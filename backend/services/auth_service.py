import os
from supabase import create_client, Client

_client: Client | None = None


def _get_client() -> Client:
    """Lazily creates the Supabase client using the service-role key.

    Service-role bypasses row-level security, unlike the anon key used by
    the Flutter app — this must only ever be used server-side for narrow,
    deliberate checks like email_exists below, never exposed to a client.
    """
    global _client
    if _client is None:
        url = os.environ["SUPABASE_URL"]
        key = os.environ["SUPABASE_KEY"]
        _client = create_client(url, key)
    return _client


def email_exists(email: str) -> bool:
    """Whether a `profiles` row exists for this email.

    Only returns a boolean — no other account details — to keep the
    account-enumeration surface as narrow as possible.
    """
    response = (
        _get_client()
        .table("profiles")
        .select("id")
        .eq("email", email)
        .limit(1)
        .execute()
    )
    return len(response.data) > 0
