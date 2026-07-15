import os

from google import genai
from google.genai import types
from pinecone import Pinecone, ServerlessSpec

# gemini-embedding-001 replaced text-embedding-004, which Google retired on
# 2026-01-14. Its natural output is 3072-dimensional; we truncate to 768 via
# output_dimensionality (Matryoshka Representation Learning — the model
# supports this natively) to keep the Pinecone index small/cheap, matching
# this project's cost-awareness convention.
_EMBED_MODEL = "gemini-embedding-001"
_DIMENSION = 768
_INDEX_NAME = os.environ.get("PINECONE_INDEX", "unilink-listings")

_client = None
_index = None


def _get_client() -> genai.Client:
    global _client
    if _client is None:
        _client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
    return _client


def _get_index():
    """Lazily connect to Pinecone, creating the index on first use so there's
    no manual dashboard step to get its dimension right."""
    global _index
    if _index is None:
        pc = Pinecone(api_key=os.environ["PINECONE_API_KEY"])
        existing = [i.name for i in pc.list_indexes()]
        if _INDEX_NAME not in existing:
            pc.create_index(
                name=_INDEX_NAME,
                dimension=_DIMENSION,
                metric="cosine",
                spec=ServerlessSpec(cloud="aws", region="us-east-1"),
            )
        _index = pc.Index(_INDEX_NAME)
    return _index


def _embed(text: str, *, is_query: bool) -> list[float]:
    """Turn text into a 768-d vector. Documents and queries use different task
    types so a query lands near the listings that answer it, not near other
    queries."""
    result = _get_client().models.embed_content(
        model=_EMBED_MODEL,
        contents=[text],
        config=types.EmbedContentConfig(
            task_type="RETRIEVAL_QUERY" if is_query else "RETRIEVAL_DOCUMENT",
            output_dimensionality=_DIMENSION,
        ),
    )
    return result.embeddings[0].values


def upsert_listing(listing_id: str, title: str, description: str, category: str) -> None:
    """Embed a listing's meaning and store the vector keyed by its id. Called
    only on create/update (not on every search) to keep embedding costs down.
    Pinecone holds only the vector + id — Supabase remains the source of truth
    for the actual listing data."""
    text = f"{title}\n{description}\nCategory: {category}"
    vector = _embed(text, is_query=False)
    _get_index().upsert(vectors=[{"id": listing_id, "values": vector}])


def delete_listing(listing_id: str) -> None:
    _get_index().delete(ids=[listing_id])


def query_listings(query: str, top_k: int = 30) -> list[str]:
    """Embed the search query and return the ids of the nearest listings, most
    relevant first."""
    vector = _embed(query, is_query=True)
    result = _get_index().query(vector=vector, top_k=top_k)
    return [match["id"] for match in result["matches"]]
