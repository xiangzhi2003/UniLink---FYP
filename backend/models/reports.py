from pydantic import BaseModel


class SellerReportResponse(BaseModel):
    period: str  # "month" | "year"
    deal_count: int
    sale_count: int
    rent_count: int
    earnings: float
    top_category: str | None = None
    earnings_change_percent: int | None = None  # vs. the previous equivalent period
    narrative: str  # AI-written summary of the numbers above
