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


def get_outstanding_debt(user_id: str) -> float:
    row = (
        get_service_client()
        .table("profiles")
        .select("outstanding_debt")
        .eq("id", user_id)
        .single()
        .execute()
        .data
    )
    return row.get("outstanding_debt") or 0


def add_debt(user_id: str, amount: float) -> None:
    current = get_outstanding_debt(user_id)
    get_service_client().table("profiles").update(
        {"outstanding_debt": current + amount}
    ).eq("id", user_id).execute()


def settle_debt(user_id: str) -> float:
    """Pays down as much outstanding debt as the current wallet balance
    covers. Returns the amount actually settled."""
    debt = get_outstanding_debt(user_id)
    if debt <= 0:
        raise ValueError("No outstanding debt")

    balance = get_balance(user_id)
    pay = min(debt, balance)
    if pay <= 0:
        raise ValueError("Insufficient wallet balance to settle debt")

    get_service_client().table("wallet_ledger").insert({
        "user_id": user_id,
        "transaction_id": None,
        "amount": -pay,
        "type": "debt_settlement",
    }).execute()
    get_service_client().table("profiles").update(
        {"outstanding_debt": debt - pay}
    ).eq("id", user_id).execute()
    return pay


def start_withdrawal(user_id: str, amount: float) -> tuple[str, str]:
    """Start a real Stripe Checkout session for a withdrawal — mode='setup'
    so it's a genuine stripe.com page (same "leave the app" rhythm as
    deposit) but collects a payment method rather than charging one, since
    Stripe Checkout can't pay money *out* without Stripe Connect (out of
    scope for this FYP). No real bank transfer happens either way; the
    actual debit is applied in [confirm_withdrawal] once this completes.
    Returns (session_id, checkout_url).
    """
    if amount <= 0:
        raise ValueError("Withdrawal amount must be positive")
    if amount > get_balance(user_id):
        raise ValueError("You can't withdraw more than your available balance")

    session = stripe.checkout.Session.create(
        mode="setup",
        payment_method_types=["card"],
        success_url=f"{_WEB_APP_URL}?wallet_withdraw=success",
        cancel_url=f"{_WEB_APP_URL}?wallet_withdraw=cancel",
        metadata={"user_id": user_id, "amount": str(amount), "type": "wallet_withdrawal"},
    )
    return session.id, session.url


def confirm_withdrawal(session_id: str) -> tuple[bool, float]:
    """Called when the app returns from Checkout. Idempotent via the unique
    index on stripe_checkout_session_id. Re-checks the balance at
    confirmation time (it may have changed since start_withdrawal) — returns
    (credited, balance), where `credited` is False if the session was never
    completed or the balance is no longer sufficient.
    """
    session = stripe.checkout.Session.retrieve(session_id)
    user_id = session.metadata.get("user_id")
    balance = get_balance(user_id)

    if session.status != "complete":
        return False, balance

    amount = float(session.metadata.get("amount", 0))
    if amount > balance:
        return False, balance

    try:
        get_service_client().table("wallet_ledger").insert({
            "user_id": user_id,
            "transaction_id": None,
            "amount": -amount,
            "type": "withdrawal",
            "stripe_checkout_session_id": session_id,
        }).execute()
    except Exception:
        pass  # already debited by an earlier call — still counts as credited

    return True, get_balance(user_id)


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
