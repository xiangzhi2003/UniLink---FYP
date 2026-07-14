import pyotp

from services.supabase_client import get_service_client

# 60-second rotation, matching the QR auto-refresh on the seller's screen.
_INTERVAL = 60


def _totp_for(secret: str) -> pyotp.TOTP:
    return pyotp.TOTP(secret, interval=_INTERVAL)


def ensure_secret(transaction_id: str) -> str:
    """Return the transaction's TOTP secret, creating+storing one on first use.

    The secret is the shared root both sides' codes derive from. It lives only
    here (in `transaction_secrets`, unreadable by any client) — the app never
    sees it, only the short rotating codes computed from it.
    """
    client = get_service_client()
    existing = (
        client.table("transaction_secrets")
        .select("totp_secret")
        .eq("transaction_id", transaction_id)
        .maybe_single()
        .execute()
    )
    # `.maybe_single().execute()` returns `None` outright (not a response
    # object with `.data=None`) when zero rows match — the first QR request
    # for any transaction always hits this.
    if existing and existing.data:
        return existing.data["totp_secret"]

    secret = pyotp.random_base32()
    client.table("transaction_secrets").insert(
        {"transaction_id": transaction_id, "totp_secret": secret}
    ).execute()
    return secret


def current_code(transaction_id: str) -> tuple[str, int]:
    """The code valid right now, plus seconds until it rotates."""
    secret = ensure_secret(transaction_id)
    totp = _totp_for(secret)
    import time

    seconds_remaining = _INTERVAL - int(time.time()) % _INTERVAL
    return totp.now(), seconds_remaining


def verify(transaction_id: str, code: str) -> bool:
    """True if `code` matches the transaction's current TOTP.

    `valid_window=1` also accepts the immediately-previous code, tolerating a
    little clock drift / the moment between the seller's screen rotating and
    the buyer scanning.
    """
    secret = ensure_secret(transaction_id)
    return _totp_for(secret).verify(code, valid_window=1)
