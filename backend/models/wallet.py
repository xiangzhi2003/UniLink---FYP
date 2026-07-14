from pydantic import BaseModel


class WalletHistoryEntry(BaseModel):
    id: str
    transaction_id: str | None
    amount: float
    type: str  # "credit" | "withdrawal" | "deposit"
    created_at: str
    listing_title: str | None
    deal_type: str | None


class WalletSummaryResponse(BaseModel):
    balance: float
    history: list[WalletHistoryEntry]


class WalletWithdrawRequest(BaseModel):
    amount: float


class WalletDepositStartRequest(BaseModel):
    amount: float


class WalletDepositStartResponse(BaseModel):
    checkout_url: str
    session_id: str


class WalletDepositConfirmRequest(BaseModel):
    session_id: str


class WalletDepositConfirmResponse(BaseModel):
    credited: bool  # False if Checkout was never actually completed
    balance: float
    history: list[WalletHistoryEntry]
