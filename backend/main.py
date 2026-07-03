from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="UniLink API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten to the deployed web origin before production
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health():
    return {"status": "ok"}
