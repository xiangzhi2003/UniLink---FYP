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
