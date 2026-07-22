# Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
# Program Name    : escrow.py
# Description     : Pydantic request/response schemas for the escrow router (checkout, confirm, refund, wallet payment).
# First Written on: Monday,06-Jul-2026
# Edited on       : Saturday,18-Jul-2026

from pydantic import BaseModel


class EscrowTransactionRequest(BaseModel):
    transaction_id: str


class EscrowCheckoutResponse(BaseModel):
    checkout_url: str


class EscrowStatusResponse(BaseModel):
    escrow_status: str  # pending | held | captured | refunded


class EscrowStartRequest(BaseModel):
    listing_id: str
    seller_id: str
    type: str  # "sale" | "rent"
    rental_days: int | None = None  # required when type == "rent"


class EscrowStartResponse(BaseModel):
    checkout_url: str
    session_id: str


class EscrowConfirmCreateRequest(BaseModel):
    session_id: str
    listing_id: str
    seller_id: str
    type: str


class EscrowConfirmCreateResponse(BaseModel):
    transaction_id: str | None
    escrow_status: str  # pending (not paid yet) | held (deal now created)


class EscrowWalletPayRequest(BaseModel):
    listing_id: str
    seller_id: str
    type: str  # "sale" | "rent"
    rental_days: int | None = None  # required when type == "rent"
