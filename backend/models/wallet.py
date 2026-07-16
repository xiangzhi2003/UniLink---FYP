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
    outstanding_debt: float = 0


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


class WalletWithdrawStartRequest(BaseModel):
    amount: float


class WalletWithdrawStartResponse(BaseModel):
    checkout_url: str
    session_id: str


class WalletWithdrawConfirmRequest(BaseModel):
    session_id: str


class WalletWithdrawConfirmResponse(BaseModel):
    credited: bool  # False if Checkout was never completed, or balance is now insufficient
    balance: float
    history: list[WalletHistoryEntry]
