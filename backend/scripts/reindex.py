"""One-time backfill: embed every existing active listing into Pinecone.

Listings created before Sprint 3C have no search vector yet. Run this once
after configuring GEMINI_API_KEY / PINECONE_API_KEY (and the Supabase
service key) to index them all:

    cd backend
    venv\\Scripts\\activate            # Windows (source venv/bin/activate on mac/linux)
    python -m scripts.reindex

After this, new/edited listings are indexed automatically by the app.
"""

from dotenv import load_dotenv

load_dotenv()

from services import embedding_service
from services.supabase_client import get_service_client


def main() -> None:
    rows = (
        get_service_client()
        .table("listings")
        .select("id, title, description, category")
        .eq("status", "active")
        .execute()
    )
    listings = rows.data or []
    print(f"Indexing {len(listings)} active listing(s)...")
    for listing in listings:
        embedding_service.upsert_listing(
            listing["id"], listing["title"], listing["description"], listing["category"]
        )
        print(f"  indexed: {listing['title']}")
    print("Done.")


if __name__ == "__main__":
    main()
