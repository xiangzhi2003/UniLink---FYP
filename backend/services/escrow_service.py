# Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
# Program Name    : escrow_service.py
# Description     : Core escrow business logic -- Stripe Checkout sessions, payment capture/refund, wallet payments, and late-fee charging.
# First Written on: Monday,06-Jul-2026
# Edited on       : Saturday,18-Jul-2026

import os
from datetime import date, timedelta

import stripe

from services import notification_service, wallet_service
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


def _notify_payment(
    transaction_id: str, seller_id: str, buyer_id: str, amount: float, listing_title: str
) -> None:
    """Notify both parties that a payment just landed in escrow. Best-effort
    — a notification failure must never break the payment flow that
    triggered it."""
    try:
        notification_service.create(
            user_id=seller_id,
            type="payment_received",
            title="Payment received",
            body=f'A buyer paid RM {amount:.2f} for "{listing_title}" — funds are held in escrow.',
            transaction_id=transaction_id,
        )
        notification_service.create(
            user_id=buyer_id,
            type="payment_successful",
            title="Payment successful",
            body=f'Your payment of RM {amount:.2f} for "{listing_title}" is held in escrow.',
            transaction_id=transaction_id,
        )
    except Exception:
        pass


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


def create_checkout_session_for_listing(
    listing_id: str,
    seller_id: str,
    buyer_id: str,
    deal_type: str,
    rental_days: int | None = None,
) -> tuple[str, str]:
    """Same idea as [create_checkout_session], but for a deal that doesn't
    exist yet — Buy/Book no longer writes a transaction row up front, so
    price/title come straight from the listing instead of via a transaction
    join. Returns (session_id, checkout_url); the transaction row is only
    created later, in [confirm_and_create], once payment is actually held.

    For rentals, `rental_days` is the buyer-selected duration; the listing's
    price is treated as the per-day rate and charged as `quantity=rental_days`
    so Stripe's own Checkout page shows the day count and multiplied total.
    """
    if deal_type == "rent" and (rental_days is None or rental_days < 1):
        raise ValueError("rental_days must be a positive integer for rent deals")

    client = get_service_client()
    listing = (
        client.table("listings")
        .select("title, price")
        .eq("id", listing_id)
        .single()
        .execute()
        .data
    )
    unit_amount = int(round(float(listing["price"]) * 100))
    quantity = rental_days if deal_type == "rent" else 1

    metadata = {
        "listing_id": listing_id,
        "seller_id": seller_id,
        "buyer_id": buyer_id,
        "type": deal_type,
    }
    if deal_type == "rent":
        metadata["rental_days"] = str(rental_days)

    session = stripe.checkout.Session.create(
        mode="payment",
        line_items=[
            {
                "price_data": {
                    "currency": "myr",
                    "product_data": {"name": listing["title"]},
                    "unit_amount": unit_amount,
                },
                "quantity": quantity,
            }
        ],
        payment_intent_data={"capture_method": "manual"},
        success_url=f"{_WEB_APP_URL}?escrow=success",
        cancel_url=f"{_WEB_APP_URL}?escrow=cancel",
        metadata=metadata,
    )
    return session.id, session.url


def confirm_and_create(
    session_id: str, listing_id: str, seller_id: str, buyer_id: str, deal_type: str
) -> tuple[str | None, str]:
    """Called when the app returns from Checkout for a not-yet-created deal.
    Only writes the transaction row once the payment is actually authorized
    and held — if the buyer abandoned Checkout, nothing is ever written.
    Idempotent: safe to call more than once for the same session (e.g. the
    user taps "I've paid" twice), since a repeat call finds the row already
    written by the first and just returns it instead of inserting again.
    Returns (transaction_id, escrow_status); transaction_id is None while
    payment is still pending.
    """
    client = get_service_client()

    existing = (
        client.table("transactions")
        .select("id, escrow_status")
        .eq("stripe_checkout_session_id", session_id)
        .maybe_single()
        .execute()
    )
    # This client version returns `None` outright (not a response object
    # with `.data=None`) when `.maybe_single()` matches zero rows — the
    # first-ever call for a new session_id always hits this.
    if existing and existing.data:
        return existing.data["id"], existing.data["escrow_status"]

    session = stripe.checkout.Session.retrieve(session_id)
    pi_id = session.payment_intent
    if not pi_id:
        return None, "pending"

    pi = stripe.PaymentIntent.retrieve(pi_id)
    if pi.status != "requires_capture":
        return None, "pending"

    listing = (
        client.table("listings")
        .select("title, price")
        .eq("id", listing_id)
        .single()
        .execute()
        .data
    )
    listing_price = float(listing["price"])

    rental_days = None
    rental_start_date = None
    rental_due_date = None
    if deal_type == "rent":
        # Read back from Stripe metadata rather than trusting a second value
        # from the app — this is the same number Stripe actually charged.
        rental_days = int(session.metadata.get("rental_days", 1))
        rental_start_date = date.today()
        rental_due_date = rental_start_date + timedelta(days=rental_days)
        amount = listing_price * rental_days
    else:
        amount = listing_price

    row = (
        client.table("transactions")
        .insert(
            {
                "listing_id": listing_id,
                "buyer_id": buyer_id,
                "seller_id": seller_id,
                "type": deal_type,
                "escrow_status": "held",
                "stripe_checkout_session_id": session_id,
                "stripe_payment_intent_id": pi_id,
                "amount": amount,
                "rental_days": rental_days,
                "rental_start_date": rental_start_date.isoformat() if rental_start_date else None,
                "rental_due_date": rental_due_date.isoformat() if rental_due_date else None,
            }
        )
        .execute()
    )
    transaction_id = row.data[0]["id"]
    _notify_payment(transaction_id, seller_id, buyer_id, amount, listing["title"])
    return transaction_id, "held"


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


def pay_with_wallet(
    listing_id: str,
    seller_id: str,
    buyer_id: str,
    deal_type: str,
    rental_days: int | None = None,
) -> str:
    """Pay for a listing straight from the buyer's simulated wallet balance
    instead of Stripe Checkout. Unlike the Stripe flow there's no async
    "did they actually pay" step to wait for, so the transaction is created
    already held in one call. Raises ValueError if the balance is insufficient
    or (for rentals) if rental_days is missing.
    """
    if deal_type == "rent" and (rental_days is None or rental_days < 1):
        raise ValueError("rental_days must be a positive integer for rent deals")

    client = get_service_client()
    listing = (
        client.table("listings").select("title, price").eq("id", listing_id).single().execute().data
    )
    listing_price = float(listing["price"])

    rental_start_date = rental_due_date = None
    if deal_type == "rent":
        amount = listing_price * rental_days
        rental_start_date = date.today()
        rental_due_date = rental_start_date + timedelta(days=rental_days)
    else:
        amount = listing_price
        rental_days = None

    # Not perfectly race-safe against two concurrent wallet payments from the
    # same buyer, but acceptable for this FYP's single-user testing scope.
    if amount > wallet_service.get_balance(buyer_id):
        raise ValueError("Insufficient wallet balance")

    row = client.table("transactions").insert({
        "listing_id": listing_id,
        "buyer_id": buyer_id,
        "seller_id": seller_id,
        "type": deal_type,
        "escrow_status": "held",
        "amount": amount,
        "rental_days": rental_days,
        "rental_start_date": rental_start_date.isoformat() if rental_start_date else None,
        "rental_due_date": rental_due_date.isoformat() if rental_due_date else None,
    }).execute()
    transaction_id = row.data[0]["id"]

    client.table("wallet_ledger").insert({
        "user_id": buyer_id,
        "transaction_id": transaction_id,
        "amount": -amount,
        "type": "wallet_payment",
    }).execute()

    _notify_payment(transaction_id, seller_id, buyer_id, amount, listing["title"])
    return transaction_id


def capture(transaction_id: str) -> None:
    """Release the held funds to the platform (the handover is confirmed).

    (In a full Stripe Connect setup this is where a transfer to the seller's
    connected account would happen; for this test-mode FYP we capture to the
    platform account and treat that as "released to seller". Wallet-funded
    deals have no Stripe PaymentIntent to capture — the buyer's side was
    already debited at payment time — so this only credits the seller.)
    """
    txn = _load_transaction(transaction_id)
    if txn["escrow_status"] != "held":
        return

    pi_id = txn.get("stripe_payment_intent_id")
    if pi_id:
        stripe.PaymentIntent.capture(pi_id)

    client = get_service_client()
    client.table("transactions").update(
        {"escrow_status": "captured"}
    ).eq("id", transaction_id).execute()

    # Credit the seller's simulated wallet for the captured amount. Wrapped
    # so a duplicate call (capture() is otherwise idempotent) can't double
    # credit — the unique index on wallet_ledger(transaction_id, type) rejects it.
    amount = txn.get("amount") or txn["listings"]["price"]
    try:
        client.table("wallet_ledger").insert({
            "user_id": txn["seller_id"],
            "transaction_id": transaction_id,
            "amount": amount,
            "type": "credit",
        }).execute()
    except Exception:
        pass

    listing_title = txn["listings"]["title"]
    try:
        notification_service.create(
            user_id=txn["seller_id"],
            type="payment_released",
            title="Payment released",
            body=f'RM {amount:.2f} for "{listing_title}" has been released to your wallet.',
            transaction_id=transaction_id,
        )
        notification_service.create(
            user_id=txn["buyer_id"],
            type="deal_completed",
            title="Deal completed",
            body=f'Your handover for "{listing_title}" is confirmed. Thanks for trading safely!',
            transaction_id=transaction_id,
        )
    except Exception:
        pass


def charge_late_fee(transaction_id: str) -> float:
    """Charge a late fee for an overdue rental return, deducted from the
    buyer's wallet and credited to the seller's -- both already-built
    wallet_ledger, no new Stripe charge. If the buyer's balance can't cover
    the full fee, charge what's available and track the rest as debt
    (blocks the buyer from starting new rentals until settled, enforced in
    routers/escrow.py). Returns the full fee that should have applied (0 if
    not overdue) so the caller can report it even on a partial charge.
    """
    txn = _load_transaction(transaction_id)
    if txn["type"] != "rent" or txn["status"] != "active" or not txn.get("rental_due_date"):
        return 0.0

    # rental_due_date is stored as a plain date, but if the column ever came
    # back as a timestamp string (e.g. "2026-07-20T00:00:00+00:00"),
    # date.fromisoformat() would reject it outright -- slicing to the first
    # 10 chars ("YYYY-MM-DD") is robust to either shape.
    due = date.fromisoformat(txn["rental_due_date"][:10])
    days_overdue = (date.today() - due).days
    if days_overdue <= 0:
        return 0.0

    rental_days = txn.get("rental_days") or 1
    amount = txn.get("amount") or txn["listings"]["price"]
    daily_rate = amount / rental_days
    fee = round(daily_rate * days_overdue, 2)

    buyer_id = txn["buyer_id"]
    seller_id = txn["seller_id"]
    charged = min(fee, max(wallet_service.get_balance(buyer_id), 0))

    client = get_service_client()
    if charged > 0:
        try:
            client.table("wallet_ledger").insert({
                "user_id": buyer_id,
                "transaction_id": transaction_id,
                "amount": -charged,
                "type": "late_fee_charge",
            }).execute()
            client.table("wallet_ledger").insert({
                "user_id": seller_id,
                "transaction_id": transaction_id,
                "amount": charged,
                "type": "late_fee_credit",
            }).execute()
        except Exception as e:
            # Expected on a retried call (unique index on transaction_id+type
            # rejects the duplicate) -- but print so a *different* failure
            # (e.g. a schema mismatch) still shows up in Railway logs instead
            # of vanishing silently.
            print(f"charge_late_fee: wallet_ledger insert failed for {transaction_id}: {e}")

    shortfall = round(fee - charged, 2)
    if shortfall > 0:
        # Tracked against this specific transaction (not a lump sum on the
        # buyer's profile) so settling it later credits the right seller --
        # see wallet_service.settle_debt.
        client.table("transactions").update(
            {"late_fee_owed": shortfall}
        ).eq("id", transaction_id).execute()

    listing_title = txn["listings"]["title"]
    try:
        notification_service.create(
            user_id=buyer_id,
            type="late_fee_charged",
            title="Late fee applied",
            body=f'A late fee of RM {fee:.2f} was applied for the overdue return of "{listing_title}".',
            transaction_id=transaction_id,
        )
    except Exception:
        pass

    return fee


def refund(transaction_id: str) -> None:
    """Release the hold without charging the buyer (deal cancelled before
    pickup). Cancelling a not-yet-captured PaymentIntent frees the held funds
    for Stripe-funded deals; wallet-funded deals get the debited amount
    credited straight back to the buyer's wallet instead.
    """
    txn = _load_transaction(transaction_id)
    client = get_service_client()

    if txn["escrow_status"] == "held":
        pi_id = txn.get("stripe_payment_intent_id")
        if pi_id:
            stripe.PaymentIntent.cancel(pi_id)
        else:
            amount = txn.get("amount") or txn["listings"]["price"]
            try:
                client.table("wallet_ledger").insert({
                    "user_id": txn["buyer_id"],
                    "transaction_id": transaction_id,
                    "amount": amount,
                    "type": "refund",
                }).execute()
            except Exception:
                pass

    client.table("transactions").update(
        {"escrow_status": "refunded", "status": "cancelled"}
    ).eq("id", transaction_id).execute()

    listing_title = txn["listings"]["title"]
    try:
        notification_service.create(
            user_id=txn["buyer_id"],
            type="refund_processed",
            title="Refund processed",
            body=f'Your payment for "{listing_title}" was refunded — the deal was cancelled.',
            transaction_id=transaction_id,
        )
        notification_service.create(
            user_id=txn["seller_id"],
            type="deal_cancelled",
            title="Deal cancelled",
            body=f'The deal for "{listing_title}" was cancelled before pickup.',
            transaction_id=transaction_id,
        )
    except Exception:
        pass
