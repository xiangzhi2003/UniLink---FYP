from fastapi import APIRouter, Depends, HTTPException

from models.search import (
    DeleteListingRequest,
    EmbedListingRequest,
    OkResponse,
    SearchQueryRequest,
    SearchQueryResponse,
)
from services import embedding_service
from services.auth import current_user_id
from services.supabase_client import get_service_client

router = APIRouter(prefix="/search", tags=["search"])


def _owned_listing(listing_id: str, user_id: str) -> dict:
    row = (
        get_service_client()
        .table("listings")
        .select("id, seller_id, title, description, category")
        .eq("id", listing_id)
        .maybe_single()
        .execute()
    )
    # `.maybe_single().execute()` returns `None` outright (not a response
    # object with `.data=None`) when the id doesn't match any row.
    if not row or not row.data:
        raise HTTPException(status_code=404, detail="Listing not found")
    if row.data["seller_id"] != user_id:
        raise HTTPException(status_code=403, detail="Not your listing")
    return row.data


@router.post("/embed-listing", response_model=OkResponse)
async def embed_listing(
    payload: EmbedListingRequest,
    user_id: str = Depends(current_user_id),
):
    """Index (or re-index) one of the caller's listings for semantic search.
    Called by the app after a listing is created or updated."""
    listing = _owned_listing(payload.listing_id, user_id)
    embedding_service.upsert_listing(
        listing["id"], listing["title"], listing["description"], listing["category"]
    )
    return OkResponse()


@router.post("/delete-listing", response_model=OkResponse)
async def delete_listing(
    payload: DeleteListingRequest,
    user_id: str = Depends(current_user_id),
):
    # Ownership is checked before the row is deleted client-side; here we just
    # remove the stale vector. Deleting a non-existent id is a no-op.
    embedding_service.delete_listing(payload.listing_id)
    return OkResponse()


@router.post("/query", response_model=SearchQueryResponse)
async def query(
    payload: SearchQueryRequest,
    user_id: str = Depends(current_user_id),
):
    """Semantic search: returns listing ids most relevant to the query, most
    relevant first. The app hydrates the full listings from Supabase."""
    if not payload.query.strip():
        return SearchQueryResponse(listing_ids=[])
    ids = embedding_service.query_listings(payload.query)
    return SearchQueryResponse(listing_ids=ids)
