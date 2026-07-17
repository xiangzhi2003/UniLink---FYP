from datetime import date

from services import generation_service
from services.supabase_client import get_service_client


def _period_bounds(period: str, today: date) -> tuple[date, date, date, date]:
    """Returns (current_start, current_end_exclusive, previous_start,
    previous_end_exclusive) for the given period ('month' or 'year')."""
    if period == "year":
        current_start = date(today.year, 1, 1)
        current_end = date(today.year + 1, 1, 1)
        previous_start = date(today.year - 1, 1, 1)
        previous_end = current_start
    else:
        current_start = date(today.year, today.month, 1)
        current_end = (
            date(today.year, today.month + 1, 1)
            if today.month < 12
            else date(today.year + 1, 1, 1)
        )
        previous_start = (
            date(today.year, today.month - 1, 1)
            if today.month > 1
            else date(today.year - 1, 12, 1)
        )
        previous_end = current_start
    return current_start, current_end, previous_start, previous_end


def _stats_for(client, seller_id: str, start: date, end: date) -> dict:
    rows = (
        client.table("transactions")
        .select("type, amount, listings(category)")
        .eq("seller_id", seller_id)
        .eq("status", "completed")
        .gte("created_at", start.isoformat())
        .lt("created_at", end.isoformat())
        .execute()
        .data
    )
    sale_count = sum(1 for r in rows if r["type"] == "sale")
    rent_count = sum(1 for r in rows if r["type"] == "rent")
    earnings = sum(r.get("amount") or 0 for r in rows)

    categories: dict[str, int] = {}
    for r in rows:
        cat = (r.get("listings") or {}).get("category") or "Others"
        categories[cat] = categories.get(cat, 0) + 1
    top_category = max(categories, key=categories.get) if categories else None

    return {
        "deal_count": sale_count + rent_count,
        "sale_count": sale_count,
        "rent_count": rent_count,
        "earnings": round(earnings, 2),
        "top_category": top_category,
    }


def generate_seller_report(user_id: str, period: str) -> dict:
    """Computes real stats for the current + previous period from
    `transactions` (deterministic, always correct), then asks Gemini to
    turn only those numbers into a short narrative -- explicitly forbidden
    from inventing anything. Same "AI narrates, math decides the facts"
    split already used for the wallet's late-fee/price logic."""
    client = get_service_client()
    today = date.today()
    current_start, current_end, previous_start, previous_end = _period_bounds(period, today)

    current = _stats_for(client, user_id, current_start, current_end)
    previous = _stats_for(client, user_id, previous_start, previous_end)

    earnings_change = None
    if previous["earnings"] > 0:
        earnings_change = round(
            (current["earnings"] - previous["earnings"]) / previous["earnings"] * 100
        )

    prompt = (
        "You are writing a short, encouraging performance summary for a "
        "student seller on UniLink, a campus marketplace app. Use ONLY the "
        "numbers given below -- do not invent, estimate, or assume anything "
        "not explicitly stated.\n\n"
        f"Period: this {period}\n"
        f"Completed deals: {current['deal_count']} "
        f"({current['sale_count']} sales, {current['rent_count']} rentals)\n"
        f"Total earnings: RM{current['earnings']:.2f}\n"
        f"Top category: {current['top_category'] or 'none'}\n"
        f"Previous {period}'s earnings: RM{previous['earnings']:.2f}\n"
        + (
            f"Change vs previous {period}: {earnings_change:+d}%\n"
            if earnings_change is not None
            else ""
        )
        + "\nWrite 2-4 short sentences: summarize the performance, note the "
        "trend if there's a meaningful change, and end with one brief "
        "encouraging or practical tip. Plain text, no markdown, no bullet points."
    )
    try:
        narrative = generation_service.generate_text(prompt)
    except Exception:
        narrative = "Report generated, but the AI summary is temporarily unavailable."

    return {
        "period": period,
        "deal_count": current["deal_count"],
        "sale_count": current["sale_count"],
        "rent_count": current["rent_count"],
        "earnings": current["earnings"],
        "top_category": current["top_category"],
        "earnings_change_percent": earnings_change,
        "narrative": narrative,
    }
