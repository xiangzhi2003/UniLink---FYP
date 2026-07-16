from pydantic import BaseModel


class AdminStatsResponse(BaseModel):
    users: int
    active_listings: int
    total_listings: int
    deals: int
    completed_deals: int
    reviews: int
    open_reports: int
    listings_by_category: dict[str, int]


class AdminOkResponse(BaseModel):
    ok: bool = True


class RemoveListingRequest(BaseModel):
    listing_id: str


class SetSuspendedRequest(BaseModel):
    user_id: str
    suspended: bool


class ResolveReportRequest(BaseModel):
    report_id: str


class AdminUser(BaseModel):
    id: str
    email: str | None = None
    full_name: str | None = None
    university: str | None = None
    role: str = "student"
    suspended: bool = False


class AdminUsersResponse(BaseModel):
    users: list[AdminUser]


class AdminReport(BaseModel):
    id: str
    reason: str
    status: str  # open | resolved
    created_at: str
    reporter_name: str | None = None
    listing_id: str | None = None
    listing_title: str | None = None  # set when a listing was reported
    reported_user_id: str | None = None
    reported_user_name: str | None = None  # set when a user was reported


class AdminReportsResponse(BaseModel):
    reports: list[AdminReport]
