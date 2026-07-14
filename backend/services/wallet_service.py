import os

import stripe

from services.supabase_client import get_service_client

stripe.api_key = os.environ.get("STRIPE_SECRET_KEY", "")

_WEB_APP_URL = os.environ.get(
    "WEB_APP_URL", "https://unilink-fyp-production.up.railway.app"
)


def get_balance(user_id: str) -> float:
    rows = (
        get_service_client()
        .table("wallet_ledger")
        .select("amount")
        .eq("user_id", user_id)
        .execute()
        .data
    )
    return sum(row["amount"] for row in rows)


def withdraw(user_id: str, amount: float) -> float:
    """Simulated cash-out: no real bank transfer happens (test-mode FYP
    scope, same as escrow capture never reaching a real seller account) —
    this just posts a debit entry so the balance and history reflect it.
    Returns the new balance.
    """
    if amount <= 0:
        raise ValueError("Withdrawal amount must be positive")

    balance = get_balance(user_id)
    if amount > balance:
        raise ValueError("You can't withdraw more than your available balance")

    get_service_client().table("wallet_ledger").insert({
        "user_id": user_id,
        "transaction_id": None,
        "amount": -amount,
        "type": "withdrawal",
    }).execute()
    return balance - amount


def start_deposit(user_id: str, amount: float) -> tuple[str, str]:
    """Start a Stripe Checkout session for the user to top up their own
    wallet. Unlike escrow, this captures immediately (no manual-capture
    hold) since it's the same person paying themselves, not an escrow.
    Returns (session_id, checkout_url).
    """
    if amount <= 0:
        raise ValueError("Deposit amount must be positive")

    session = stripe.checkout.Session.create(
        mode="payment",
        line_items=[
            {
                "price_data": {
                    "currency": "myr",
                    "product_data": {"name": "UniLink wallet top-up"},
                    "unit_amount": int(round(amount * 100)),
                },
                "quantity": 1,
            }
        ],
        success_url=f"{_WEB_APP_URL}?wallet_topup=success",
        cancel_url=f"{_WEB_APP_URL}?wallet_topup=cancel",
        metadata={"user_id": user_id, "amount": str(amount), "type": "wallet_topup"},
    )
    return session.id, session.url


def confirm_deposit(session_id: str) -> tuple[bool, float]:
    """Called when the app returns from Checkout. Idempotent: a repeat call
    for an already-credited session hits the unique index on
    stripe_checkout_session_id and is a no-op. Returns (credited, balance) —
    `credited` is False if the buyer backed out of Checkout without paying,
    so the caller can tell the user the deposit isn't in yet instead of
    falsely reporting success.
    """
    session = stripe.checkout.Session.retrieve(session_id)
    user_id = session.metadata.get("user_id")

    if session.payment_status != "paid":
        return False, get_balance(user_id)

    amount = float(session.metadata.get("amount", 0))
    try:
        get_service_client().table("wallet_ledger").insert({
            "user_id": user_id,
            "transaction_id": None,
            "amount": amount,
            "type": "deposit",
            "stripe_checkout_session_id": session_id,
        }).execute()
    except Exception:
        pass  # already credited by an earlier call — still counts as credited

    return True, get_balance(user_id)
