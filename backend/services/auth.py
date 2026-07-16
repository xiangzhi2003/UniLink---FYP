from fastapi import Depends, Header, HTTPException, status

from services.supabase_client import get_service_client


async def current_user_id(authorization: str = Header(default="")) -> str:
    """FastAPI dependency: validate the caller's Supabase access token and
    return their user id.

    The Flutter app sends its logged-in session token as
    `Authorization: Bearer <token>`. We hand it to Supabase to verify it's
    genuine and unexpired, so backend endpoints can trust who's calling and
    check they're actually a party to the transaction they're acting on.
    """
    if not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
        )

    token = authorization.split(" ", 1)[1].strip()
    try:
        response = get_service_client().auth.get_user(token)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    if response is None or response.user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )
    return response.user.id


async def current_admin_id(user_id: str = Depends(current_user_id)) -> str:
    """FastAPI dependency for admin-only endpoints: on top of verifying
    identity, checks the caller's profiles.role is 'admin'. Admin status is
    granted manually in the database (no in-app path), so this lookup is
    the single gate every /admin route sits behind."""
    row = (
        get_service_client()
        .table("profiles")
        .select("role")
        .eq("id", user_id)
        .maybe_single()
        .execute()
    )
    if not row or not row.data or row.data.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return user_id
