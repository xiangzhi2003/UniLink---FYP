from pydantic import BaseModel


class EscrowTransactionRequest(BaseModel):
    transaction_id: str


class EscrowCheckoutResponse(BaseModel):
    checkout_url: str


class EscrowStatusResponse(BaseModel):
    escrow_status: str  # pending | held | captured | refunded
