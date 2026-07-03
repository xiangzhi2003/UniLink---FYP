from fastapi import APIRouter

from models.auth import CheckEmailRequest
from services.auth_service import email_exists

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/check-email")
async def check_email(payload: CheckEmailRequest):
    return {"exists": email_exists(payload.email)}
