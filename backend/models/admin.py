# Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
# Program Name    : admin.py
# Description     : Pydantic request/response schemas for the admin router (stats, listings, users, reports, knowledge docs).
# First Written on: Friday,17-Jul-2026
# Edited on       : Saturday,18-Jul-2026

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


class KnowledgeDoc(BaseModel):
    id: str
    title: str
    body: str
    created_at: str


class KnowledgeDocsResponse(BaseModel):
    docs: list[KnowledgeDoc]


class CreateKnowledgeDocRequest(BaseModel):
    title: str
    body: str


class DeleteKnowledgeDocRequest(BaseModel):
    doc_id: str
