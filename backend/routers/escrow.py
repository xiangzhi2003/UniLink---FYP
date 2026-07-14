import traceback

from fastapi import APIRouter, Depends, HTTPException, status

from models.escrow import (
    EscrowCheckoutResponse,
    EscrowConfirmCreateRequest,
    EscrowConfirmCreateResponse,
    EscrowStartRequest,
    EscrowStartResponse,
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


@router.post("/start", response_model=EscrowStartResponse)
async def start(
    payload: EscrowStartRequest,
    user_id: str = Depends(current_user_id),
):
    """Buyer starts payment for a listing directly — no transaction row is
    created here. One only gets written in /confirm-and-create, once payment
    is actually held, so tapping Buy/Book and never paying leaves no trace."""
    if user_id == payload.seller_id:
        raise HTTPException(status_code=400, detail="You can't buy your own listing")

    session_id, url = escrow_service.create_checkout_session_for_listing(
        payload.listing_id, payload.seller_id, user_id, payload.type
    )
    return EscrowStartResponse(checkout_url=url, session_id=session_id)


@router.post("/confirm-and-create", response_model=EscrowConfirmCreateResponse)
async def confirm_and_create(
    payload: EscrowConfirmCreateRequest,
    user_id: str = Depends(current_user_id),
):
    """Called when the app returns from Checkout for a deal started via
    /start. Creates the transaction for the first time, but only if payment
    is confirmed held — otherwise returns a null transaction_id so the app
    knows to keep waiting. Idempotent."""
    try:
        transaction_id, escrow_status = escrow_service.confirm_and_create(
            payload.session_id, payload.listing_id, payload.seller_id, user_id, payload.type
        )
    except Exception:
        # TODO(debug): temporary — surfaces the real traceback instead of a
        # generic plain-text 500, so the actual bug can be found. Remove once
        # confirm-and-create is confirmed working end to end.
        raise HTTPException(status_code=500, detail=traceback.format_exc())
    return EscrowConfirmCreateResponse(
        transaction_id=transaction_id, escrow_status=escrow_status
    )


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
