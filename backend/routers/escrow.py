from fastapi import APIRouter, Depends, HTTPException, status

from models.escrow import (
    EscrowCheckoutResponse,
    EscrowStatusResponse,
    EscrowTransactionRequest,
)
from services import escrow_service
from services.auth import current_user_id
from services.supabase_client import get_service_client

router = APIRouter(prefix="/escrow", tags=["escrow"])


def _load_transaction(transaction_id: str) -> dict:
    row = (
        get_service_client()
        .table("transactions")
        .select("*")
        .eq("id", transaction_id)
        .maybe_single()
        .execute()
    )
    if not row.data:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return row.data


@router.post("/create", response_model=EscrowCheckoutResponse)
async def create(
    payload: EscrowTransactionRequest,
    user_id: str = Depends(current_user_id),
):
    """Buyer starts payment: returns a Stripe Checkout URL for the app to open."""
    txn = _load_transaction(payload.transaction_id)
    if user_id != txn["buyer_id"]:
        raise HTTPException(status_code=403, detail="Only the buyer pays")
    if txn["escrow_status"] != "pending":
        raise HTTPException(status_code=400, detail="Payment already started")

    url = escrow_service.create_checkout_session(payload.transaction_id)
    return EscrowCheckoutResponse(checkout_url=url)


@router.post("/confirm", response_model=EscrowStatusResponse)
async def confirm(
    payload: EscrowTransactionRequest,
    user_id: str = Depends(current_user_id),
):
    """Called when the app returns from Checkout — syncs whether the money is
    now held. Idempotent."""
    txn = _load_transaction(payload.transaction_id)
    if user_id not in (txn["buyer_id"], txn["seller_id"]):
        raise HTTPException(status_code=403, detail="Not your transaction")

    new_status = escrow_service.confirm_payment(payload.transaction_id)
    return EscrowStatusResponse(escrow_status=new_status)


@router.post("/refund", response_model=EscrowStatusResponse)
async def refund(
    payload: EscrowTransactionRequest,
    user_id: str = Depends(current_user_id),
):
    """Cancel the deal and release the hold — only allowed before pickup."""
    txn = _load_transaction(payload.transaction_id)
    if user_id not in (txn["buyer_id"], txn["seller_id"]):
        raise HTTPException(status_code=403, detail="Not your transaction")
    if txn["pickup_scanned_at"] is not None:
        raise HTTPException(status_code=400, detail="Too late to cancel — item already picked up")
    if txn["status"] in ("completed", "cancelled"):
        raise HTTPException(status_code=400, detail="This deal is already closed")

    escrow_service.refund(payload.transaction_id)
    return EscrowStatusResponse(escrow_status="refunded")
