import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status

from models.qr import (
    QrCurrentRequest,
    QrCurrentResponse,
    QrVerifyRequest,
    QrVerifyResponse,
)
from services import escrow_service, totp_service
from services.auth import current_user_id
from services.supabase_client import get_service_client

router = APIRouter(prefix="/qr", tags=["qr"])


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
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found")
    return row.data


def _phase(txn: dict) -> str:
    """Which leg of the handshake is next.

    'pickup' until the item changes hands; for rentals, 'return' after that.
    """
    if txn["pickup_scanned_at"] is None:
        return "pickup"
    return "return"


def _giver_and_receiver(txn: dict) -> tuple[str, str]:
    """Who shows the QR (giver) and who scans it (receiver) for the current
    phase. Pickup: seller gives -> buyer receives. Return: buyer gives back ->
    seller receives.
    """
    if _phase(txn) == "pickup":
        return txn["seller_id"], txn["buyer_id"]
    return txn["buyer_id"], txn["seller_id"]


@router.post("/current", response_model=QrCurrentResponse)
async def qr_current(
    payload: QrCurrentRequest,
    user_id: str = Depends(current_user_id),
):
    """Called by the party who should *show* the QR right now. Returns the
    current rotating code wrapped in the QR payload."""
    txn = _load_transaction(payload.transaction_id)

    if txn["status"] in ("completed", "cancelled"):
        raise HTTPException(status_code=400, detail="This deal is already closed")

    giver, _ = _giver_and_receiver(txn)
    if user_id != giver:
        raise HTTPException(status_code=403, detail="It's not your turn to show the code")

    code, expires_in = totp_service.current_code(payload.transaction_id)
    qr_payload = json.dumps({"transaction_id": payload.transaction_id, "code": code})
    return QrCurrentResponse(payload=qr_payload, expires_in=expires_in)


@router.post("/verify", response_model=QrVerifyResponse)
async def qr_verify(
    payload: QrVerifyRequest,
    user_id: str = Depends(current_user_id),
):
    """Called by the party who *scanned* the QR. Verifies the code and advances
    the handshake."""
    txn = _load_transaction(payload.transaction_id)

    if txn["status"] in ("completed", "cancelled"):
        raise HTTPException(status_code=400, detail="This deal is already closed")

    phase = _phase(txn)
    giver, receiver = _giver_and_receiver(txn)
    if user_id != receiver:
        raise HTTPException(status_code=403, detail="It's not your turn to scan")

    if not totp_service.verify(payload.transaction_id, payload.code):
        raise HTTPException(status_code=400, detail="Code is wrong or expired — ask for a fresh one")

    now = datetime.now(timezone.utc).isoformat()
    client = get_service_client()

    if phase == "pickup":
        # Sale: pickup is the whole deal -> completed. Rent: now in progress.
        new_status = "completed" if txn["type"] == "sale" else "active"
        client.table("transactions").update(
            {"pickup_scanned_at": now, "status": new_status, "updated_at": now}
        ).eq("id", payload.transaction_id).execute()
        # For a sale the handover is now complete -> release the held escrow.
        if txn["type"] == "sale":
            escrow_service.capture(payload.transaction_id)
        return QrVerifyResponse(status=new_status, phase="pickup", message="Pickup confirmed!")

    # Return leg (rentals only) -> completed. The rental is over, so this is
    # where the held escrow is released to the seller.
    client.table("transactions").update(
        {"return_scanned_at": now, "status": "completed", "updated_at": now}
    ).eq("id", payload.transaction_id).execute()
    escrow_service.capture(payload.transaction_id)
    return QrVerifyResponse(status="completed", phase="return", message="Return confirmed!")
