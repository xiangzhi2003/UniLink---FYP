import logging

from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import escrow, qr, search

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("unilink")

app = FastAPI(title="UniLink API")

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


@app.on_event("startup")
async def on_startup():
    logger.info("UniLink API starting up")


@app.get("/")
async def root():
    return {"service": "UniLink API", "status": "ok"}


@app.get("/health")
async def health():
    return {"status": "ok"}
