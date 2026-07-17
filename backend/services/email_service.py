import os

import httpx

_API_KEY = os.environ.get("RESEND_API_KEY", "")
_FROM = os.environ.get("RESEND_FROM_EMAIL", "UniLink <onboarding@resend.dev>")


def send_email(to: str, subject: str, html_body: str) -> None:
    """Sends a transactional email via Resend. No-ops silently if
    RESEND_API_KEY isn't configured -- callers still wrap this in try/except
    regardless, since email delivery must never block a real app flow."""
    if not _API_KEY:
        return
    httpx.post(
        "https://api.resend.com/emails",
        headers={"Authorization": f"Bearer {_API_KEY}"},
        json={"from": _FROM, "to": [to], "subject": subject, "html": html_body},
        timeout=10,
    )
