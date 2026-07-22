# Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
# Program Name    : test_email.py
# Description     : One-off manual script for demoing the rental reminder email during a presentation; not part of the deployed app.
# First Written on: Sunday,19-Jul-2026
# Edited on       : Sunday,19-Jul-2026

"""One-off script for demoing the rental reminder email during
presentation. Not part of the app -- run manually, not imported anywhere."""
from dotenv import load_dotenv

load_dotenv()

from datetime import date

from services import email_service
from services.supabase_client import get_service_client

RECIPIENT = "xiangzhichiang@gmail.com"  # change to whichever inbox you want to demo with


def main():
    client = get_service_client()
    today = date.today()
    rows = (
        client.table("transactions")
        .select(
            "id, buyer_id, rental_due_date, rental_days, amount, "
            "listings(title), buyer:profiles!buyer_id(email, full_name)"
        )
        .eq("type", "rent")
        .eq("rental_due_date", today.isoformat())
        .execute()
        .data
    )

    if not rows:
        print("No rental due today -- sending a generic sample email instead.")
        subject = 'Reminder: "Sample Item" is due back today'
        html_body = (
            "<p>Hi there,</p>"
            '<p>Your rental of "Sample Item" is due back today.</p>'
            "<p>Please return it — if it isn't returned by the end of "
            "today, a late fee of RM10.00 will be charged for each day "
            "it's overdue.</p>"
        )
    else:
        txn = rows[0]
        daily_rate = round(txn["amount"] / (txn["rental_days"] or 1), 2)
        listing_title = (txn.get("listings") or {}).get("title", "your rental")
        buyer = txn.get("buyer") or {}

        subject = f'Reminder: "{listing_title}" is due back today'
        html_body = (
            f"<p>Hi {buyer.get('full_name') or 'there'},</p>"
            f'<p>Your rental of "{listing_title}" is due back today.</p>'
            f"<p>Please return it — if it isn't returned by the end of "
            f"today, a late fee of RM{daily_rate:.2f} will be charged "
            f"for each day it's overdue.</p>"
        )

    print("Subject:", subject)
    print("Body:", html_body)
    email_service.send_email(to=RECIPIENT, subject=subject, html_body=html_body)
    print(f"Sent to {RECIPIENT}")


if __name__ == "__main__":
    main()
