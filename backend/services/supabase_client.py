import os

from supabase import Client, create_client

_client: Client | None = None


def get_service_client() -> Client:
    """Supabase client using the service-role key.

    Service-role bypasses row-level security, so this must only ever be used
    server-side. It's what lets the backend read/write `transaction_secrets`
    (which no client can touch) and advance transaction state.
    """
    global _client
    if _client is None:
        url = os.environ["SUPABASE_URL"]
        key = os.environ["SUPABASE_KEY"]
        _client = create_client(url, key)
    return _client
