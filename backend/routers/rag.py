from fastapi import APIRouter, HTTPException

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
