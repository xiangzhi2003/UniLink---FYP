from pydantic import BaseModel


class WalletHistoryEntry(BaseModel):
    id: str
    transaction_id: str
    amount: float
    type: str
    created_at: str
    listing_title: str | None
    deal_type: str | None


class WalletSummaryResponse(BaseModel):
    balance: float
    history: list[WalletHistoryEntry]
