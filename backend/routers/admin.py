from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException

from models.admin import (
    AdminOkResponse,
    AdminReport,
    AdminReportsResponse,
    AdminStatsResponse,
    AdminUser,
    AdminUsersResponse,
    CreateKnowledgeDocRequest,
    DeleteKnowledgeDocRequest,
    KnowledgeDoc,
    KnowledgeDocsResponse,
    RemoveListingRequest,
    ResolveReportRequest,
    SetSuspendedRequest,
)
from services import embedding_service
from services.auth import current_admin_id
from services.supabase_client import get_service_client

router = APIRouter(prefix="/admin", tags=["admin"])

# Kept in sync with Listing.categories on the frontend and _ALLOWED_CATEGORIES
# in routers/search.py -- listing categories are a fixed, small set.
_CATEGORIES = ["Textbooks", "Electronics", "Equipment", "Others"]


def _count(table: str, **filters) -> int:
    query = get_service_client().table(table).select("id", count="exact")
    for column, value in filters.items():
        query = query.eq(column, value)
    return query.execute().count or 0


@router.get("/stats", response_model=AdminStatsResponse)
async def stats(admin_id: str = Depends(current_admin_id)):
    """Marketplace-wide counts for the admin dashboard. Uses the
    service-role client, so these are true totals, not RLS-scoped."""
    return AdminStatsResponse(
        users=_count("profiles"),
        active_listings=_count("listings", status="active"),
        total_listings=_count("listings"),
        deals=_count("transactions"),
        completed_deals=_count("transactions", status="completed"),
        reviews=_count("reviews"),
        open_reports=_count("reports", status="open"),
        listings_by_category={
            category: _count("listings", category=category) for category in _CATEGORIES
        },
    )


@router.get("/listings")
async def all_listings(admin_id: str = Depends(current_admin_id)):
    """Every listing regardless of status/owner, newest first. Returns raw
    rows in the same shape the app's own listing queries use
    (`profiles(full_name)` join) so the frontend parses them with the
    existing Listing.fromJson."""
    rows = (
        get_service_client()
        .table("listings")
        .select("*, profiles(full_name)")
        .order("created_at", desc=True)
        .execute()
        .data
    )
    return {"listings": rows}


@router.post("/listings/remove", response_model=AdminOkResponse)
async def remove_listing(
    payload: RemoveListingRequest,
    admin_id: str = Depends(current_admin_id),
):
    """Moderation removal: deletes the listing row AND its Pinecone vector
    in one place, so admin deletes can't leave orphan search vectors (the
    seller-side delete does these as two separate client calls)."""
    get_service_client().table("listings").delete().eq("id", payload.listing_id).execute()
    try:
        embedding_service.delete_listing(payload.listing_id)
    except Exception:
        pass  # vector cleanup is best-effort; the listing itself is gone
    return AdminOkResponse()


@router.get("/users", response_model=AdminUsersResponse)
async def all_users(admin_id: str = Depends(current_admin_id)):
    rows = (
        get_service_client()
        .table("profiles")
        .select("id, email, full_name, university, role, suspended")
        .order("full_name")
        .execute()
        .data
    )
    return AdminUsersResponse(
        users=[
            AdminUser(
                id=row["id"],
                email=row.get("email"),
                full_name=row.get("full_name"),
                university=row.get("university"),
                role=row.get("role") or "student",
                suspended=bool(row.get("suspended")),
            )
            for row in rows
        ]
    )


@router.post("/users/set-suspended", response_model=AdminOkResponse)
async def set_suspended(
    payload: SetSuspendedRequest,
    admin_id: str = Depends(current_admin_id),
):
    if payload.user_id == admin_id:
        raise HTTPException(status_code=400, detail="You can't suspend yourself")

    target = (
        get_service_client()
        .table("profiles")
        .select("role")
        .eq("id", payload.user_id)
        .maybe_single()
        .execute()
    )
    if not target or not target.data:
        raise HTTPException(status_code=404, detail="User not found")
    if target.data.get("role") == "admin":
        raise HTTPException(status_code=400, detail="You can't suspend another admin")

    get_service_client().table("profiles").update(
        {"suspended": payload.suspended}
    ).eq("id", payload.user_id).execute()
    return AdminOkResponse()


@router.get("/reports", response_model=AdminReportsResponse)
async def all_reports(admin_id: str = Depends(current_admin_id)):
    """All user-filed reports, open ones first, newest first within each."""
    rows = (
        get_service_client()
        .table("reports")
        .select(
            "*, reporter:profiles!reporter_id(full_name), "
            "reported:profiles!reported_user_id(full_name), listings(title)"
        )
        .order("status", desc=False)  # 'open' < 'resolved' alphabetically
        .order("created_at", desc=True)
        .execute()
        .data
    )
    return AdminReportsResponse(
        reports=[
            AdminReport(
                id=row["id"],
                reason=row["reason"],
                status=row["status"],
                created_at=row["created_at"],
                reporter_name=(row.get("reporter") or {}).get("full_name"),
                listing_id=row.get("listing_id"),
                listing_title=(row.get("listings") or {}).get("title"),
                reported_user_id=row.get("reported_user_id"),
                reported_user_name=(row.get("reported") or {}).get("full_name"),
            )
            for row in rows
        ]
    )


@router.post("/reports/resolve", response_model=AdminOkResponse)
async def resolve_report(
    payload: ResolveReportRequest,
    admin_id: str = Depends(current_admin_id),
):
    get_service_client().table("reports").update(
        {
            "status": "resolved",
            "resolved_at": datetime.now(timezone.utc).isoformat(),
        }
    ).eq("id", payload.report_id).execute()
    return AdminOkResponse()


@router.get("/knowledge", response_model=KnowledgeDocsResponse)
async def all_knowledge_docs(admin_id: str = Depends(current_admin_id)):
    rows = (
        get_service_client()
        .table("knowledge_docs")
        .select("*")
        .order("created_at", desc=True)
        .execute()
        .data
    )
    return KnowledgeDocsResponse(
        docs=[
            KnowledgeDoc(id=row["id"], title=row["title"], body=row["body"],
                         created_at=row["created_at"])
            for row in rows
        ]
    )


@router.post("/knowledge", response_model=KnowledgeDoc)
async def create_knowledge_doc(
    payload: CreateKnowledgeDocRequest,
    admin_id: str = Depends(current_admin_id),
):
    """Stores the doc in Supabase (source of truth) then embeds it into
    Pinecone's 'knowledge' namespace so the per-listing chatbot's retrieval
    step can find it."""
    row = (
        get_service_client()
        .table("knowledge_docs")
        .insert({"title": payload.title, "body": payload.body})
        .execute()
        .data[0]
    )
    try:
        embedding_service.upsert_knowledge_doc(row["id"], payload.title, payload.body)
    except Exception:
        pass  # the doc itself is saved; a retrieval hiccup shouldn't block that
    return KnowledgeDoc(
        id=row["id"], title=row["title"], body=row["body"], created_at=row["created_at"]
    )


@router.post("/knowledge/delete", response_model=AdminOkResponse)
async def delete_knowledge_doc(
    payload: DeleteKnowledgeDocRequest,
    admin_id: str = Depends(current_admin_id),
):
    get_service_client().table("knowledge_docs").delete().eq("id", payload.doc_id).execute()
    try:
        embedding_service.delete_knowledge_doc(payload.doc_id)
    except Exception:
        pass
    return AdminOkResponse()
