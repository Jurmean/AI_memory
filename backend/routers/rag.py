import json

from fastapi import APIRouter, HTTPException
from sse_starlette.sse import EventSourceResponse

from models.schemas import RAGQueryRequest, RAGResponse
from services import rag_service

router = APIRouter(prefix="/api/rag", tags=["RAG"])


@router.post("/query", response_model=RAGResponse)
async def query(req: RAGQueryRequest):
    try:
        result = await rag_service.rag_query(
            question=req.question,
            context=req.context,
            use_web_search=req.use_web_search,
            use_local_kb=req.use_local_kb,
            top_k=req.top_k,
        )
        return RAGResponse(**result)
    except Exception as e:
        raise HTTPException(502, detail=str(e))


@router.post("/query/stream")
async def query_stream(req: RAGQueryRequest):
    """SSE streaming RAG: first event = sources JSON, then delta chunks from LLM."""

    async def event_gen():
        try:
            async for kind, payload in rag_service.rag_query_stream(
                question=req.question,
                context=req.context,
                use_web_search=req.use_web_search,
                use_local_kb=req.use_local_kb,
                top_k=req.top_k,
            ):
                if kind == "sources":
                    yield {"event": "sources", "data": json.dumps(payload, ensure_ascii=False)}
                elif kind == "delta":
                    yield {"event": "delta", "data": payload}
        except Exception as e:
            yield {"event": "error", "data": str(e)}

    return EventSourceResponse(event_gen(), media_type="text/event-stream")
