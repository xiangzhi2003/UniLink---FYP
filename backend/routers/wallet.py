import traceback

from fastapi import APIRouter, Depends, HTTPException

from models.wallet import (
    WalletDepositConfirmRequest,
    WalletDepositConfirmResponse,
    WalletDepositStartRequest,
    WalletDepositStartResponse,
    WalletHistoryEntry,
    WalletSummaryResponse,
    WalletWithdrawConfirmRequest,
    WalletWithdrawConfirmResponse,
    WalletWithdrawStartRequest,
    WalletWithdrawStartResponse,
)
from services import wallet_service
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


@router.post("/withdraw/start", response_model=WalletWithdrawStartResponse)
async def withdraw_start(
    payload: WalletWithdrawStartRequest,
    user_id: str = Depends(current_user_id),
):
    try:
        session_id, url = wallet_service.start_withdrawal(user_id, payload.amount)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception:
        # TODO(debug): temporary — surfaces the real traceback so the
        # "something went wrong" withdrawal bug can be found. Remove once
        # withdraw is confirmed working end to end.
        raise HTTPException(status_code=500, detail=traceback.format_exc())
    return WalletWithdrawStartResponse(checkout_url=url, session_id=session_id)


@router.post("/withdraw/confirm", response_model=WalletWithdrawConfirmResponse)
async def withdraw_confirm(
    payload: WalletWithdrawConfirmRequest,
    user_id: str = Depends(current_user_id),
):
    try:
        credited, _ = wallet_service.confirm_withdrawal(payload.session_id)
        s = await summary(user_id=user_id)
    except Exception:
        # TODO(debug): temporary — see note in withdraw_start above.
        raise HTTPException(status_code=500, detail=traceback.format_exc())
    return WalletWithdrawConfirmResponse(credited=credited, balance=s.balance, history=s.history)


@router.post("/deposit/start", response_model=WalletDepositStartResponse)
async def deposit_start(
    payload: WalletDepositStartRequest,
    user_id: str = Depends(current_user_id),
):
    try:
        session_id, url = wallet_service.start_deposit(user_id, payload.amount)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return WalletDepositStartResponse(checkout_url=url, session_id=session_id)


@router.post("/deposit/confirm", response_model=WalletDepositConfirmResponse)
async def deposit_confirm(
    payload: WalletDepositConfirmRequest,
    user_id: str = Depends(current_user_id),
):
    credited, _ = wallet_service.confirm_deposit(payload.session_id)
    s = await summary(user_id=user_id)
    return WalletDepositConfirmResponse(credited=credited, balance=s.balance, history=s.history)
