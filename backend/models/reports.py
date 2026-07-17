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
