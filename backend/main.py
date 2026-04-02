from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import llm, rag, docs, admin

app = FastAPI(
    title="智能记忆助手 Backend",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(llm.router)
app.include_router(rag.router)
app.include_router(docs.router)
app.include_router(admin.router)


@app.get("/api/health")
async def health():
    return {"status": "ok"}
