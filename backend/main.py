# Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
# Program Name    : main.py
# Description     : FastAPI application entry point -- configures CORS, registers all routers, and schedules the daily rental-reminder job.
# First Written on: Friday,03-Jul-2026
# Edited on       : Saturday,18-Jul-2026

import logging
from zoneinfo import ZoneInfo

from dotenv import load_dotenv

load_dotenv()

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import admin, escrow, qr, reports, search, wallet
from services import rental_reminder_service

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("unilink")

app = FastAPI(title="UniLink API")
scheduler = AsyncIOScheduler()

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://unilink-fyp-production-a474.up.railway.app",
        "http://localhost:5000",
    ],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(qr.router)
app.include_router(escrow.router)
app.include_router(search.router)
app.include_router(wallet.router)
app.include_router(admin.router)
app.include_router(reports.router)


@app.on_event("startup")
async def on_startup():
    logger.info("UniLink API starting up")
    scheduler.add_job(
        rental_reminder_service.check_due_today_rentals,
        "cron",
        hour=9,
        timezone=ZoneInfo("Asia/Kuala_Lumpur"),
    )
    scheduler.start()


@app.get("/")
async def root():
    return {"service": "UniLink API", "status": "ok"}


@app.get("/health")
async def health():
    return {"status": "ok"}
