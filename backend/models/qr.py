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
