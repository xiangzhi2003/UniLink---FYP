# Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
# Program Name    : reports.py
# Description     : Pydantic request/response schemas for the AI seller sales report endpoint.
# First Written on: Saturday,18-Jul-2026
# Edited on       : Saturday,18-Jul-2026

from pydantic import BaseModel


class CategoryEarnings(BaseModel):
    category: str
    count: int
    earnings: float


class TrendPoint(BaseModel):
    label: str  # day-of-month ("1".."31") for period=month, month abbrev ("Jan".."Dec") for period=year
    earnings: float


class SellerReportResponse(BaseModel):
    period: str  # "month" | "year"
    deal_count: int
    sale_count: int
    rent_count: int
    earnings: float
    top_category: str | None = None
    earnings_change_percent: int | None = None  # vs. the previous equivalent period
    category_breakdown: list[CategoryEarnings] = []  # earnings by category, highest first
    trend: list[TrendPoint] = []  # earnings time series for the current period
    narrative: str  # AI-written summary of the numbers above
