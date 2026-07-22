# Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
# Program Name    : email_service.py
# Description     : Sends transactional emails (rental due-date reminders) via Gmail SMTP.
# First Written on: Saturday,18-Jul-2026
# Edited on       : Saturday,18-Jul-2026

import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

_GMAIL_ADDRESS = os.environ.get("GMAIL_ADDRESS", "")
_GMAIL_APP_PASSWORD = os.environ.get("GMAIL_APP_PASSWORD", "")


def send_email(to: str, subject: str, html_body: str) -> None:
    """Sends a transactional email via Gmail SMTP. No-ops silently if
    GMAIL_ADDRESS/GMAIL_APP_PASSWORD aren't configured -- callers still wrap
    this in try/except regardless, since email delivery must never block a
    real app flow."""
    if not _GMAIL_ADDRESS or not _GMAIL_APP_PASSWORD:
        return

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"UniLink <{_GMAIL_ADDRESS}>"
    msg["To"] = to
    msg.attach(MIMEText(html_body, "html"))

    with smtplib.SMTP("smtp.gmail.com", 587) as server:
        server.starttls()
        server.login(_GMAIL_ADDRESS, _GMAIL_APP_PASSWORD)
        server.send_message(msg)
