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
    # `.maybe_single().execute()` returns `None` outright (not a response
    # object with `.data=None`) when the id doesn't match any row.
    if not row or not row.data:
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
        # Sale: pickup is the whole deal -> completed. Rent: now in progress
        # (still awaiting return). Either way the item has now changed hands,
        # so the seller is paid at this point for both deal types -- holding
        # a rental's payment until return would mean the seller waits the
        # entire rental period (days, weeks, longer) to get paid, which
        # doesn't match how real rental payouts work. The return leg still
        # matters for closing out the deal and the due-date record, just not
        # for money movement anymore.
        new_status = "completed" if txn["type"] == "sale" else "active"
        client.table("transactions").update(
            {"pickup_scanned_at": now, "status": new_status, "updated_at": now}
        ).eq("id", payload.transaction_id).execute()
        escrow_service.capture(payload.transaction_id)
        return QrVerifyResponse(status=new_status, phase="pickup", message="Pickup confirmed!")

    # Return leg (rentals only) -> completed. Escrow was already captured at
    # pickup; this closes out the deal and charges a late fee if overdue.
    # charge_late_fee needs status still 'active' to see this as the return
    # in progress, so it must run before the update below.
    fee_note = ""
    try:
        fee = escrow_service.charge_late_fee(payload.transaction_id)
        if fee > 0:
            fee_note = f" A late fee of RM{fee:.2f} was applied."
    except Exception:
        pass  # never block the return confirmation over a fee-charging hiccup

    client.table("transactions").update(
        {"return_scanned_at": now, "status": "completed", "updated_at": now}
    ).eq("id", payload.transaction_id).execute()
    return QrVerifyResponse(
        status="completed", phase="return", message=f"Return confirmed!{fee_note}"
    )
