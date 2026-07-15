from pydantic import BaseModel


class EmbedListingRequest(BaseModel):
    listing_id: str


class DeleteListingRequest(BaseModel):
    listing_id: str


class SearchQueryRequest(BaseModel):
    query: str


class SearchQueryResponse(BaseModel):
    listing_ids: list[str]  # most relevant first


class OkResponse(BaseModel):
    ok: bool = True


class ConversationTurn(BaseModel):
    role: str  # "user" | "assistant"
    text: str


class SuggestListingRequest(BaseModel):
    note: str | None = None
    images_base64: list[str] = []  # max 3, enforced server-side


class SuggestListingResponse(BaseModel):
    title: str
    description: str
    category: str  # always one of Listing.categories -- validated server-side
    price: float | None = None


class ListingChatRequest(BaseModel):
    listing_id: str
    message: str
    history: list[ConversationTurn] = []


class ListingChatResponse(BaseModel):
    reply: str
