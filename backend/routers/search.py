import base64
import json

from fastapi import APIRouter, Depends, HTTPException

from models.search import (
    DeleteListingRequest,
    EmbedListingRequest,
    ListingChatRequest,
    ListingChatResponse,
    OkResponse,
    PriceCheckRequest,
    PriceCheckResponse,
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
        .select("id, seller_id, title, description, category, listing_type")
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
        listing["id"],
        listing["title"],
        listing["description"],
        listing["category"],
        listing["listing_type"],
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
    """AI chatbot grounded in one specific listing — answers questions about
    that item using both its real details (fetched server-side, never
    trusted from the client) and the model's own general knowledge,
    including comparisons to other real-world brands/products. The only
    thing it's told not to do is invent *other UniLink listings*, since no
    marketplace retrieval happens here."""
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
        history_text = "\n".join(
            f'{turn.role}: {turn.text}' for turn in payload.history[-6:]
        )

        prompt = (
            "You are Gemini, acting as a knowledgeable shopping assistant embedded "
            "on a UniLink campus marketplace listing page. A student is viewing "
            "this specific listing:\n"
            f"Title: {listing['title']}\n"
            f"Description: {listing['description']}\n"
            f"Category: {listing['category']}\n"
            f"Condition: {listing['condition']}\n"
            f"Price: RM {listing['price']}"
            f"{' / day (for rent)' if listing['listing_type'] == 'rent' else ''}\n\n"
            "Treat the listing as context, not a boundary — answer naturally and "
            "helpfully like you normally would, using your full general knowledge. "
            "This includes comparing this item to other real brands, products, or "
            "alternatives the student asks about (e.g. if this listing is a "
            "specific supplement brand and the student asks how it compares to a "
            "different brand, give a genuine, informative comparison). Don't "
            "artificially restrict yourself to only this listing's own text.\n\n"
            "The one thing you must not do: don't invent or claim knowledge of "
            "*other listings currently on UniLink* — you have no access to the "
            "marketplace's other listings in this conversation. If the student "
            "asks you to find alternatives on UniLink itself, tell them to browse "
            "or search the marketplace instead.\n\n"
            "Be concise and honest.\n\n"
            f"Recent conversation:\n{history_text}\n\n"
            f"Student's message: {payload.message}"
        )
        reply = generation_service.generate_text(prompt)
        return ListingChatResponse(reply=reply)
    except Exception:
        raise HTTPException(status_code=502, detail="AI assistant is temporarily unavailable")


@router.post("/price-check", response_model=PriceCheckResponse)
async def price_check(
    payload: PriceCheckRequest,
    user_id: str = Depends(current_user_id),
):
    """Compares a listing's price against similar active listings found via
    semantic search. Retrieval is AI (Pinecone), but the verdict itself is
    plain arithmetic on real Supabase prices -- never hallucinated."""
    row = (
        get_service_client()
        .table("listings")
        .select("id, title, description, category, price, listing_type")
        .eq("id", payload.listing_id)
        .maybe_single()
        .execute()
    )
    if not row or not row.data:
        raise HTTPException(status_code=404, detail="Listing not found")
    listing = row.data

    try:
        text = f"{listing['title']}\n{listing['description']}\nCategory: {listing['category']}"
        ids = embedding_service.query_listings(text, top_k=20)
        ids = [i for i in ids if i != listing["id"]]

        comparables = []
        if ids:
            comparables = (
                get_service_client()
                .table("listings")
                .select("id, price")
                .in_("id", ids)
                .eq("status", "active")
                .eq("listing_type", listing["listing_type"])
                .execute()
                .data
            )
    except Exception:
        raise HTTPException(status_code=502, detail="Price check unavailable")

    if len(comparables) < 3:
        return PriceCheckResponse(
            verdict="insufficient_data",
            comparable_count=len(comparables),
            average_price=None,
            message="Not enough similar listings yet to compare pricing.",
        )

    prices = [c["price"] for c in comparables]
    average = sum(prices) / len(prices)
    own_price = listing["price"]
    ratio = own_price / average if average else 1.0

    if ratio <= 0.85:
        verdict = "great_deal"
        message = (
            f"Priced {round((1 - ratio) * 100)}% below the average of "
            f"RM{average:.2f} across {len(comparables)} similar listings."
        )
    elif ratio <= 1.15:
        verdict = "fair"
        message = (
            f"In line with the average of RM{average:.2f} across "
            f"{len(comparables)} similar listings."
        )
    else:
        verdict = "above_average"
        message = (
            f"Priced {round((ratio - 1) * 100)}% above the average of "
            f"RM{average:.2f} across {len(comparables)} similar listings."
        )

    return PriceCheckResponse(
        verdict=verdict,
        comparable_count=len(comparables),
        average_price=round(average, 2),
        message=message,
    )
