# Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
# Program Name    : qr.py
# Description     : Pydantic request/response schemas for the QR handshake router.
# First Written on: Monday,06-Jul-2026
# Edited on       : Monday,06-Jul-2026

from pydantic import BaseModel


class QrCurrentRequest(BaseModel):
    transaction_id: str


class QrCurrentResponse(BaseModel):
    # JSON string the seller's app renders as a QR: {"transaction_id", "code"}
    payload: str
    expires_in: int  # seconds until the code rotates


class QrVerifyRequest(BaseModel):
    transaction_id: str
    code: str


class QrVerifyResponse(BaseModel):
    status: str  # new transaction status
    phase: str  # "pickup" or "return" — which leg was just confirmed
    message: str  # human-friendly result for the UI
