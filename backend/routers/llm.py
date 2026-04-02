from fastapi import APIRouter, HTTPException
from sse_starlette.sse import EventSourceResponse

from models.schemas import ChatRequest, ChatResponse
from services import llm_service

router = APIRouter(prefix="/api/llm", tags=["LLM"])


@router.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    try:
        messages = [m.model_dump() for m in req.messages]
        if req.stream:
            raise HTTPException(400, "Use /chat/stream for streaming")
        content = await llm_service.chat_completion(
            messages, system_prompt=req.system_prompt
        )
        return ChatResponse(content=content)
    except Exception as e:
        raise HTTPException(502, detail=str(e))


@router.post("/chat/stream")
async def chat_stream(req: ChatRequest):
    messages = [m.model_dump() for m in req.messages]

    async def event_gen():
        try:
            async for line in llm_service.chat_completion_stream(
                messages, system_prompt=req.system_prompt
            ):
                yield line
        except Exception as e:
            yield f"data: {{'error': '{e}'}}"

    return EventSourceResponse(event_gen(), media_type="text/event-stream")
