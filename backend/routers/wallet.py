from fastapi import APIRouter, Depends

from models.wallet import WalletHistoryEntry, WalletSummaryResponse
from services.auth import current_user_id
from services.supabase_client import get_service_client

router = APIRouter(prefix="/wallet", tags=["wallet"])


@router.get("/summary", response_model=WalletSummaryResponse)
async def summary(user_id: str = Depends(current_user_id)):
    """The seller's simulated wallet: derived balance + earnings history."""
    rows = (
        get_service_client()
        .table("wallet_ledger")
        .select("*, transactions(type, listings(title))")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .execute()
        .data
    )

    history = [
        WalletHistoryEntry(
            id=row["id"],
            transaction_id=row["transaction_id"],
            amount=row["amount"],
            type=row["type"],
            created_at=row["created_at"],
            listing_title=(row.get("transactions") or {}).get("listings", {}).get("title"),
            deal_type=(row.get("transactions") or {}).get("type"),
        )
        for row in rows
    ]
    balance = sum(row.amount for row in history)
    return WalletSummaryResponse(balance=balance, history=history)
