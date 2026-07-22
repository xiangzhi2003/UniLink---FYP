# Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
# Program Name    : reports.py
# Description     : HTTP endpoint for a seller's own AI-narrated monthly/yearly sales report.
# First Written on: Saturday,18-Jul-2026
# Edited on       : Saturday,18-Jul-2026

from fastapi import APIRouter, Depends, HTTPException

from models.reports import SellerReportResponse
from services import seller_report_service
from services.auth import current_user_id

# Deliberately distinct from the moderation `reports` table / admin.py's
# reports endpoints (user-filed listing/user reports) -- this is a seller's
# own performance summary, an unrelated feature despite the similar name.
router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/seller-summary", response_model=SellerReportResponse)
async def seller_summary(period: str = "month", user_id: str = Depends(current_user_id)):
    """A seller's own monthly/yearly performance report -- real stats
    computed from their completed deals, narrated (not decided) by AI."""
    if period not in ("month", "year"):
        raise HTTPException(status_code=400, detail="period must be 'month' or 'year'")
    return SellerReportResponse(**seller_report_service.generate_seller_report(user_id, period))
