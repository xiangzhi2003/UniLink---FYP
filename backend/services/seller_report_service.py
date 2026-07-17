import calendar
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
        .select("type, amount, listings(title, category)")
        .eq("seller_id", seller_id)
        .eq("status", "completed")
        .gte("created_at", start.isoformat())
        .lt("created_at", end.isoformat())
        .execute()
        .data
    )
    sale_count = sum(1 for r in rows if r["type"] == "sale")
    rent_count = sum(1 for r in rows if r["type"] == "rent")
    sale_earnings = sum(r.get("amount") or 0 for r in rows if r["type"] == "sale")
    rent_earnings = sum(r.get("amount") or 0 for r in rows if r["type"] == "rent")
    earnings = sale_earnings + rent_earnings

    categories: dict[str, dict] = {}
    listings: dict[str, dict] = {}
    for r in rows:
        listing = r.get("listings") or {}
        cat = listing.get("category") or "Others"
        cat_stats = categories.setdefault(cat, {"count": 0, "earnings": 0.0})
        cat_stats["count"] += 1
        cat_stats["earnings"] += r.get("amount") or 0

        title = listing.get("title") or "Unknown item"
        item_stats = listings.setdefault(title, {"count": 0, "earnings": 0.0})
        item_stats["count"] += 1
        item_stats["earnings"] += r.get("amount") or 0

    top_category = max(categories, key=lambda c: categories[c]["count"]) if categories else None
    top_listing = (
        max(listings, key=lambda t: listings[t]["earnings"]) if listings else None
    )

    deal_count = sale_count + rent_count
    return {
        "deal_count": deal_count,
        "sale_count": sale_count,
        "rent_count": rent_count,
        "earnings": round(earnings, 2),
        "sale_earnings": round(sale_earnings, 2),
        "rent_earnings": round(rent_earnings, 2),
        "avg_deal_value": round(earnings / deal_count, 2) if deal_count else 0,
        "categories": categories,
        "top_category": top_category,
        "top_listing": top_listing,
        "top_listing_earnings": round(listings[top_listing]["earnings"], 2) if top_listing else None,
        "top_listing_count": listings[top_listing]["count"] if top_listing else None,
    }


def _trend_for(client, seller_id: str, start: date, end: date, period: str, today: date) -> list[dict]:
    """Earnings time series for the current period only -- daily points for
    'month' (up to today, since the rest of the month hasn't happened yet),
    monthly points for 'year' (up to the current month). Powers the line
    chart; deliberately separate from _stats_for since that aggregates by
    category/listing, not by time bucket."""
    rows = (
        client.table("transactions")
        .select("amount, created_at")
        .eq("seller_id", seller_id)
        .eq("status", "completed")
        .gte("created_at", start.isoformat())
        .lt("created_at", end.isoformat())
        .execute()
        .data
    )

    if period == "year":
        buckets = {m: 0.0 for m in range(1, today.month + 1)}
        for r in rows:
            month = int(r["created_at"][5:7])
            if month in buckets:
                buckets[month] += r.get("amount") or 0
        return [
            {"label": calendar.month_abbr[m], "earnings": round(buckets[m], 2)}
            for m in sorted(buckets)
        ]

    last_day = today.day if today.year == start.year and today.month == start.month else (
        calendar.monthrange(start.year, start.month)[1]
    )
    buckets = {d: 0.0 for d in range(1, last_day + 1)}
    for r in rows:
        day = int(r["created_at"][8:10])
        if day in buckets:
            buckets[day] += r.get("amount") or 0
    return [{"label": str(d), "earnings": round(buckets[d], 2)} for d in sorted(buckets)]


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
    trend = _trend_for(client, user_id, current_start, current_end, period, today)

    has_history = previous["deal_count"] > 0
    earnings_change = None
    if has_history and previous["earnings"] > 0:
        earnings_change = round(
            (current["earnings"] - previous["earnings"]) / previous["earnings"] * 100
        )
    deal_count_change = current["deal_count"] - previous["deal_count"] if has_history else None

    category_breakdown = [
        {"category": cat, "count": stats["count"], "earnings": round(stats["earnings"], 2)}
        for cat, stats in sorted(
            current["categories"].items(), key=lambda kv: -kv[1]["earnings"]
        )
    ]
    category_lines = (
        ", ".join(
            f"{c['category']} ({c['count']} deal{'s' if c['count'] != 1 else ''}, RM{c['earnings']:.2f})"
            for c in category_breakdown
        )
        if category_breakdown
        else "none"
    )

    if current["deal_count"] == 0:
        # No activity at all this period -- comparing to anything, even "no
        # history", would just be noise. A distinct, honest prompt instead of
        # forcing the trend-comparison structure onto empty data.
        prompt = (
            "You are writing a short, encouraging message for a student seller "
            "on UniLink, a campus marketplace app, who has not completed any "
            f"deals this {period} yet. Use ONLY the facts given -- do not invent "
            "any numbers. Write 2-3 short sentences: acknowledge there's no "
            "activity yet this period, and give one practical, encouraging "
            "suggestion to get their first deal (e.g. list an item, price it "
            "competitively, add clear photos). Plain text, no markdown."
        )
    elif not has_history:
        # First-ever active period for this seller -- there's genuinely
        # nothing to compare against, so the prompt must not ask for a trend.
        prompt = (
            "You are writing an encouraging, insightful performance summary for "
            "a student seller on UniLink, a campus marketplace app. This is "
            f"their first {period} with any completed deals, so there is NO "
            "previous period to compare against -- do not mention growth, "
            "decline, or any comparison to a previous period. Use ONLY the "
            "numbers given below -- do not invent, estimate, or assume anything "
            "not explicitly stated. When you mention a category or item, use "
            "its exact name from the data below.\n\n"
            f"Period: this {period} (first period with activity)\n"
            f"Completed deals: {current['deal_count']} "
            f"({current['sale_count']} sales, {current['rent_count']} rentals)\n"
            f"Total earnings: RM{current['earnings']:.2f} "
            f"(RM{current['sale_earnings']:.2f} from sales, RM{current['rent_earnings']:.2f} from rentals)\n"
            f"Average earnings per deal: RM{current['avg_deal_value']:.2f}\n"
            f"Earnings by category, highest first: {category_lines}\n"
            + (
                f"Best-earning item: \"{current['top_listing']}\" — "
                f"{current['top_listing_count']} deal(s), RM{current['top_listing_earnings']:.2f} total\n"
                if current["top_listing"]
                else ""
            )
            + "\nWrite 4-6 sentences covering: (1) a welcoming summary of this "
            "first period's performance, (2) which specific category earned "
            "the most and how it compares to the others by name, (3) a callout "
            "of the best-earning item by name if one is given, and (4) one "
            "concrete, practical suggestion for next period grounded in the "
            "numbers above. Plain text, no markdown, no bullet points."
        )
    else:
        prev_category_lines = (
            ", ".join(
                f"{cat} ({stats['count']})"
                for cat, stats in sorted(
                    previous["categories"].items(), key=lambda kv: -kv[1]["count"]
                )
            )
            if previous["categories"]
            else "none"
        )
        prompt = (
            "You are writing an encouraging, insightful performance summary for a "
            "student seller on UniLink, a campus marketplace app. Use ONLY the "
            "numbers given below -- do not invent, estimate, or assume anything "
            "not explicitly stated. When you mention a category or item, use its "
            "exact name from the data below.\n\n"
            f"Period: this {period}\n"
            f"Completed deals: {current['deal_count']} "
            f"({current['sale_count']} sales, {current['rent_count']} rentals)\n"
            f"Total earnings: RM{current['earnings']:.2f} "
            f"(RM{current['sale_earnings']:.2f} from sales, RM{current['rent_earnings']:.2f} from rentals)\n"
            f"Average earnings per deal: RM{current['avg_deal_value']:.2f}\n"
            f"Earnings by category, highest first: {category_lines}\n"
            + (
                f"Best-earning item: \"{current['top_listing']}\" — "
                f"{current['top_listing_count']} deal(s), RM{current['top_listing_earnings']:.2f} total\n"
                if current["top_listing"]
                else ""
            )
            + f"Previous {period} -- deals: {previous['deal_count']}, earnings: RM{previous['earnings']:.2f}, "
            f"categories: {prev_category_lines}\n"
            f"Change in deal count vs previous {period}: {deal_count_change:+d}\n"
            + (
                f"Change in earnings vs previous {period}: {earnings_change:+d}%\n"
                if earnings_change is not None
                else ""
            )
            + "\nWrite 5-7 sentences covering: (1) an overall summary of this "
            "period's performance, (2) how it compares to the previous period by "
            "name (deal count and earnings trend), (3) which specific category "
            "earned the most and how it compares to the others by name, (4) a "
            "callout of the best-earning item by name if one is given, and (5) "
            "one concrete, practical suggestion for next period grounded in the "
            "numbers above (e.g. lean into the top category, or diversify away "
            "from a single category). Plain text, no markdown, no bullet points."
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
        "category_breakdown": category_breakdown,
        "trend": trend,
        "narrative": narrative,
    }
