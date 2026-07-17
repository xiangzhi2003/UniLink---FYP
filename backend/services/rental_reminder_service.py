from datetime import date

from services import email_service, notification_service
from services.supabase_client import get_service_client


def check_overdue_rentals() -> None:
    """Runs once daily (see main.py's scheduler). Finds active rentals past
    their due date that haven't been notified today, sends an in-app
    notification + email for each, and stamps last_overdue_notified_at so a
    server restart mid-day can't double-send."""
    client = get_service_client()
    today = date.today()
    rows = (
        client.table("transactions")
        .select(
            "id, buyer_id, rental_due_date, rental_days, amount, last_overdue_notified_at, "
            "listings(title), buyer:profiles!buyer_id(email, full_name)"
        )
        .eq("type", "rent")
        .eq("status", "active")
        .lt("rental_due_date", today.isoformat())
        .execute()
        .data
    )

    for txn in rows:
        if txn.get("last_overdue_notified_at") == today.isoformat():
            continue

        due = date.fromisoformat(txn["rental_due_date"][:10])
        days_overdue = (today - due).days
        daily_rate = txn["amount"] / (txn["rental_days"] or 1)
        fee_so_far = round(daily_rate * days_overdue, 2)
        listing_title = (txn.get("listings") or {}).get("title", "your rental")
        buyer = txn.get("buyer") or {}
        buyer_id = txn.get("buyer_id")

        try:
            notification_service.create(
                user_id=buyer_id,
                type="rental_overdue",
                title="Rental overdue",
                body=(
                    f'"{listing_title}" was due back {days_overdue} day'
                    f'{"s" if days_overdue != 1 else ""} ago. Return it or extend '
                    f"your rental — a late fee of RM{fee_so_far:.2f} applies so far."
                ),
                transaction_id=txn["id"],
            )
        except Exception:
            pass

        if buyer.get("email"):
            try:
                email_service.send_email(
                    to=buyer["email"],
                    subject=f'Overdue: "{listing_title}" on UniLink',
                    html_body=(
                        f"<p>Hi {buyer.get('full_name') or 'there'},</p>"
                        f'<p>Your rental of "{listing_title}" was due back on {due} '
                        f"and is now {days_overdue} day(s) overdue.</p>"
                        f"<p>Please return it or extend your rental in the app — "
                        f"a late fee of RM{fee_so_far:.2f} applies so far and grows "
                        f"daily until it's resolved.</p>"
                    ),
                )
            except Exception:
                pass

        client.table("transactions").update(
            {"last_overdue_notified_at": today.isoformat()}
        ).eq("id", txn["id"]).execute()
