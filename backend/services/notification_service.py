# Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
# Program Name    : notification_service.py
# Description     : Inserts an in-app notification row via the service-role Supabase client.
# First Written on: Tuesday,14-Jul-2026
# Edited on       : Tuesday,14-Jul-2026

from services.supabase_client import get_service_client


def create(
    user_id: str,
    type: str,
    title: str,
    body: str,
    transaction_id: str | None = None,
) -> None:
    """Insert a notification via the service-role client. Callers wrap this
    in try/except so a notification failure never breaks the payment flow
    that triggered it (same spirit as escrow_service.capture()'s
    wallet_ledger insert)."""
    get_service_client().table("notifications").insert({
        "user_id": user_id,
        "type": type,
        "title": title,
        "body": body,
        "transaction_id": transaction_id,
    }).execute()
