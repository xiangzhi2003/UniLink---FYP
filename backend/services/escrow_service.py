import os

import stripe

from services.supabase_client import get_service_client

stripe.api_key = os.environ.get("STRIPE_SECRET_KEY", "")

# Where Stripe sends the browser back to after the hosted Checkout page.
_WEB_APP_URL = os.environ.get(
    "WEB_APP_URL", "https://unilink-fyp-production.up.railway.app"
)


def _load_transaction(transaction_id: str) -> dict:
    client = get_service_client()
    row = (
        client.table("transactions")
        .select("*, listings(title, price)")
        .eq("id", transaction_id)
        .single()
        .execute()
    )
    return row.data


def create_checkout_session(transaction_id: str) -> str:
    """Create a Stripe Checkout session with **manual capture** and return its
    hosted URL.

    Manual capture is the escrow trick: when the buyer completes Checkout the
    payment is only *authorized* (the money is held on their card, status
    `requires_capture`) — it isn't actually taken. We capture it later, once
    the QR handshake proves the handover happened, or cancel it to release the
    hold if the deal falls through.
    """
    txn = _load_transaction(transaction_id)
    listing = txn["listings"]
    amount = int(round(float(listing["price"]) * 100))  # RM -> sen (cents)

    session = stripe.checkout.Session.create(
        mode="payment",
        line_items=[
            {
                "price_data": {
                    "currency": "myr",
                    "product_data": {"name": listing["title"]},
                    "unit_amount": amount,
                },
                "quantity": 1,
            }
        ],
        payment_intent_data={"capture_method": "manual"},
        success_url=f"{_WEB_APP_URL}?escrow=success",
        cancel_url=f"{_WEB_APP_URL}?escrow=cancel",
        metadata={"transaction_id": transaction_id},
    )

    get_service_client().table("transactions").update(
        {"stripe_checkout_session_id": session.id}
    ).eq("id", transaction_id).execute()
    return session.url


def confirm_payment(transaction_id: str) -> str:
    """Check whether the buyer finished paying, and if so record the held
    payment. Idempotent — safe to call whenever the app returns from Checkout.
    Returns the resulting escrow_status.
    """
    txn = _load_transaction(transaction_id)
    session_id = txn.get("stripe_checkout_session_id")
    if not session_id:
        return txn["escrow_status"]

    session = stripe.checkout.Session.retrieve(session_id)
    pi_id = session.payment_intent
    if not pi_id:
        return txn["escrow_status"]

    pi = stripe.PaymentIntent.retrieve(pi_id)
    # requires_capture == authorized & held (our "escrow held" state).
    if pi.status == "requires_capture":
        get_service_client().table("transactions").update(
            {"stripe_payment_intent_id": pi_id, "escrow_status": "held"}
        ).eq("id", transaction_id).execute()
        return "held"
    return txn["escrow_status"]


def capture(transaction_id: str) -> None:
    """Release the held funds to the platform (the handover is confirmed).

    (In a full Stripe Connect setup this is where a transfer to the seller's
    connected account would happen; for this test-mode FYP we capture to the
    platform account and treat that as "released to seller".)
    """
    txn = _load_transaction(transaction_id)
    pi_id = txn.get("stripe_payment_intent_id")
    if txn["escrow_status"] != "held" or not pi_id:
        return
    stripe.PaymentIntent.capture(pi_id)
    get_service_client().table("transactions").update(
        {"escrow_status": "captured"}
    ).eq("id", transaction_id).execute()


def refund(transaction_id: str) -> None:
    """Release the hold without charging the buyer (deal cancelled before
    pickup). Cancelling a not-yet-captured PaymentIntent frees the held funds.
    """
    txn = _load_transaction(transaction_id)
    pi_id = txn.get("stripe_payment_intent_id")
    if pi_id and txn["escrow_status"] == "held":
        stripe.PaymentIntent.cancel(pi_id)
    get_service_client().table("transactions").update(
        {"escrow_status": "refunded", "status": "cancelled"}
    ).eq("id", transaction_id).execute()
