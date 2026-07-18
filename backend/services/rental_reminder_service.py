from datetime import date

from services import email_service, notification_service
from services.supabase_client import get_service_client


def check_due_today_rentals() -> None:
    """Runs once daily (see main.py's scheduler). Finds active rentals due
    back TODAY (not yet overdue) that haven't been reminded today, and sends
    a single in-app notification + email nudging the buyer to return it,
    mentioning that a daily late fee kicks in if they don't. Stamps
    last_overdue_notified_at so a server restart mid-day can't double-send --
    this is the buyer's only reminder; nothing fires again after today even
    if the item is never returned (the late fee itself is still charged via
    the existing return-scan logic, independent of this reminder)."""
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
        .eq("rental_due_date", today.isoformat())
        .execute()
        .data
    )

    for txn in rows:
        if txn.get("last_overdue_notified_at") == today.isoformat():
            continue

        daily_rate = round(txn["amount"] / (txn["rental_days"] or 1), 2)
        listing_title = (txn.get("listings") or {}).get("title", "your rental")
        buyer = txn.get("buyer") or {}
        buyer_id = txn.get("buyer_id")

        try:
            notification_service.create(
                user_id=buyer_id,
                type="rental_due_today",
                title="Rental due today",
                body=(
                    f'"{listing_title}" is due back today — a late fee of '
                    f"RM{daily_rate:.2f}/day applies if it's not returned by end of day."
                ),
                transaction_id=txn["id"],
            )
        except Exception:
            pass

        if buyer.get("email"):
            try:
                email_service.send_email(
                    to=buyer["email"],
                    subject=f'Reminder: "{listing_title}" is due back today',
                    html_body=(
                        f"<p>Hi {buyer.get('full_name') or 'there'},</p>"
                        f'<p>Your rental of "{listing_title}" is due back today.</p>'
                        f"<p>Please return it — if it isn't returned by the end of "
                        f"today, a late fee of RM{daily_rate:.2f} will be charged "
                        f"for each day it's overdue.</p>"
                    ),
                )
            except Exception as e:
                # Never block the reminder over an email hiccup -- but print
                # so a real failure (bad credentials, blocked SMTP, etc.)
                # shows up in Railway logs instead of vanishing silently.
                print(f"check_due_today_rentals: email send failed for {txn['id']}: {e}")

        client.table("transactions").update(
            {"last_overdue_notified_at": today.isoformat()}
        ).eq("id", txn["id"]).execute()
