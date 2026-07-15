import base64
import json

from fastapi import APIRouter, Depends, HTTPException

from models.search import (
    ConciergeRequest,
    ConciergeResponse,
    DeleteListingRequest,
    EmbedListingRequest,
    ListingChatRequest,
    ListingChatResponse,
    OkResponse,
    SearchQueryRequest,
    SearchQueryResponse,
    SuggestListingRequest,
    SuggestListingResponse,
)
from services import embedding_service, generation_service
from services.auth import current_user_id
from services.supabase_client import get_service_client

_ALLOWED_CATEGORIES = {"Textbooks", "Electronics", "Equipment", "Others"}

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


@router.post("/concierge", response_model=ConciergeResponse)
async def concierge(
    payload: ConciergeRequest,
    user_id: str = Depends(current_user_id),
):
    """Conversational AI search — retrieves matching listings the same way
    /query does, then asks Gemini to write a short, friendly reply
    referencing only those listings."""
    message = payload.message.strip()
    if not message:
        return ConciergeResponse(
            reply="What are you looking for? Tell me what you need!",
            listing_ids=[],
        )

    try:
        ids = embedding_service.query_listings(message, top_k=6)

        summaries = []
        if ids:
            rows = (
                get_service_client()
                .table("listings")
                .select("id, title, price, category")
                .in_("id", ids)
                .eq("status", "active")
                .execute()
                .data
            )
            by_id = {row["id"]: row for row in rows}
            summaries = [by_id[i] for i in ids if i in by_id]

        listings_text = (
            "\n".join(
                f'- "{s["title"]}" (RM {s["price"]}, {s["category"]})' for s in summaries
            )
            if summaries
            else "(no matching listings found)"
        )
        history_text = "\n".join(
            f'{turn.role}: {turn.text}' for turn in payload.history[-6:]
        )

        prompt = (
            "You are UniLink's campus marketplace concierge, helping university "
            "students buy and rent items from each other. Be concise and friendly "
            "(2-3 sentences). Only reference the listings given below — never "
            "invent items that aren't listed. If nothing matches, say so plainly "
            "and suggest the student try different words.\n\n"
            f"Matching listings:\n{listings_text}\n\n"
            f"Recent conversation:\n{history_text}\n\n"
            f"Student's message: {message}"
        )
        reply = generation_service.generate_text(prompt)
        return ConciergeResponse(reply=reply, listing_ids=[s["id"] for s in summaries])
    except Exception:
        raise HTTPException(status_code=502, detail="AI concierge is temporarily unavailable")


@router.post("/suggest-listing", response_model=SuggestListingResponse)
async def suggest_listing(
    payload: SuggestListingRequest,
    user_id: str = Depends(current_user_id),
):
    """AI-assisted listing creation: suggest a title/description/category/
    price from a seller's rough note and/or photos."""
    if len(payload.images_base64) > 3:
        raise HTTPException(status_code=400, detail="Max 3 photos")

    try:
        images = [base64.b64decode(b) for b in payload.images_base64]
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image data")

    note_text = payload.note.strip() if payload.note else "(no note provided)"
    prompt = (
        "You are a listing assistant for UniLink, a campus marketplace where "
        "students buy, sell, and rent items. Based on the seller's rough note "
        "and/or attached photos, suggest a clear, honest listing.\n\n"
        f"Seller's note: {note_text}\n\n"
        "Respond with strict JSON only, no other text, with exactly these keys:\n"
        '- "title": a short, clear listing title\n'
        '- "description": a 1-3 sentence description\n'
        '- "category": exactly one of "Textbooks", "Electronics", "Equipment", "Others"\n'
        '- "price": a fair price in RM as a number (or null if you can\'t estimate one)'
    )

    try:
        raw = generation_service.generate_text(prompt, images=images, json_mode=True)
        parsed = json.loads(raw)
    except Exception:
        raise HTTPException(status_code=502, detail="Couldn't generate a suggestion, try again")

    category = parsed.get("category")
    if category not in _ALLOWED_CATEGORIES:
        category = "Others"

    title = str(parsed.get("title") or "").strip()[:80] or "Untitled listing"
    description = str(parsed.get("description") or "").strip() or "No description provided."

    price = parsed.get("price")
    try:
        price = float(price) if price is not None and float(price) >= 0 else None
    except (TypeError, ValueError):
        price = None

    return SuggestListingResponse(
        title=title, description=description, category=category, price=price
    )


@router.post("/listing-chat", response_model=ListingChatResponse)
async def listing_chat(
    payload: ListingChatRequest,
    user_id: str = Depends(current_user_id),
):
    """AI chatbot scoped to one specific listing — answers questions about
    that item using both its real details (fetched server-side, never
    trusted from the client) and the model's own general knowledge, and can
    point to similar listings already on the marketplace."""
    row = (
        get_service_client()
        .table("listings")
        .select("id, title, description, category, price, condition, listing_type")
        .eq("id", payload.listing_id)
        .maybe_single()
        .execute()
    )
    if not row or not row.data:
        raise HTTPException(status_code=404, detail="Listing not found")
    listing = row.data

    try:
        related_ids: list[str] = []
        try:
            candidates = embedding_service.query_listings(
                f"{listing['title']} {listing['category']}", top_k=5
            )
            related_ids = [i for i in candidates if i != listing["id"]][:4]
        except Exception:
            related_ids = []  # related-item suggestions are a nice-to-have, not essential

        related_summaries = []
        if related_ids:
            rows = (
                get_service_client()
                .table("listings")
                .select("id, title, price, category")
                .in_("id", related_ids)
                .eq("status", "active")
                .execute()
                .data
            )
            by_id = {r["id"]: r for r in rows}
            related_summaries = [by_id[i] for i in related_ids if i in by_id]

        related_text = (
            "\n".join(
                f'- "{s["title"]}" (RM {s["price"]}, {s["category"]})' for s in related_summaries
            )
            if related_summaries
            else "(none found)"
        )
        history_text = "\n".join(
            f'{turn.role}: {turn.text}' for turn in payload.history[-6:]
        )

        prompt = (
            "You are a helpful assistant embedded on a UniLink campus marketplace "
            "listing page. A student is viewing this listing:\n"
            f"Title: {listing['title']}\n"
            f"Description: {listing['description']}\n"
            f"Category: {listing['category']}\n"
            f"Condition: {listing['condition']}\n"
            f"Price: RM {listing['price']}"
            f"{' / day (for rent)' if listing['listing_type'] == 'rent' else ''}\n\n"
            "Answer their questions about this item. You may use your own general "
            "knowledge about this type of product (how it's used, tips, safety "
            "notes, typical value) in addition to the listing's own details. Be "
            "concise and honest. If relevant, you can mention these other similar "
            "listings already on the marketplace:\n"
            f"{related_text}\n\n"
            f"Recent conversation:\n{history_text}\n\n"
            f"Student's message: {payload.message}"
        )
        reply = generation_service.generate_text(prompt)
        return ListingChatResponse(
            reply=reply, related_listing_ids=[s["id"] for s in related_summaries]
        )
    except Exception:
        raise HTTPException(status_code=502, detail="AI assistant is temporarily unavailable")
