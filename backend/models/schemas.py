from pydantic import BaseModel, Field


# ── LLM ──────────────────────────────────────────
class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    system_prompt: str | None = None
    stream: bool = False


class ChatResponse(BaseModel):
    content: str


# ── RAG ──────────────────────────────────────────
class RAGQueryRequest(BaseModel):
    question: str
    context: str | None = None
    use_web_search: bool = True
    use_local_kb: bool = True
    top_k: int = 5


class RAGSource(BaseModel):
    title: str
    snippet: str
    url: str | None = None
    source_type: str = "web"  # "web" | "local"


class RAGResponse(BaseModel):
    answer: str
    sources: list[RAGSource] = []


# ── Documents / Vector Store ─────────────────────
class DocTextInput(BaseModel):
    title: str = ""
    content: str
    metadata: dict | None = None


class DocUploadResponse(BaseModel):
    doc_id: str
    chunk_count: int


class DocListItem(BaseModel):
    doc_id: str
    title: str
    chunk_count: int
