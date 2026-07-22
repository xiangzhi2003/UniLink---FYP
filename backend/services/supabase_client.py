# Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
# Program Name    : supabase_client.py
# Description     : Provides the service-role Supabase client used for all privileged backend reads/writes.
# First Written on: Monday,06-Jul-2026
# Edited on       : Monday,06-Jul-2026

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
