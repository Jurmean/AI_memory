from fastapi import APIRouter, HTTPException, UploadFile, File, Form

from models.schemas import DocTextInput, DocUploadResponse, DocListItem
from services import vector_service

router = APIRouter(prefix="/api/docs", tags=["Documents"])


@router.post("/text", response_model=DocUploadResponse)
async def add_text(req: DocTextInput):
    """Add raw text to the knowledge base."""
    if not req.content.strip():
        raise HTTPException(400, "content cannot be empty")
    doc_id, count = vector_service.add_document(
        title=req.title,
        content=req.content,
        metadata=req.metadata,
    )
    return DocUploadResponse(doc_id=doc_id, chunk_count=count)


@router.post("/upload", response_model=DocUploadResponse)
async def upload_file(
    file: UploadFile = File(...),
    title: str = Form(""),
):
    """Upload a .txt / .md file to the knowledge base."""
    raw = await file.read()
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        text = raw.decode("gbk", errors="replace")

    if not text.strip():
        raise HTTPException(400, "uploaded file is empty")

    doc_id, count = vector_service.add_document(
        title=title or file.filename or "upload",
        content=text,
    )
    return DocUploadResponse(doc_id=doc_id, chunk_count=count)


@router.get("/list", response_model=list[DocListItem])
async def list_docs():
    """List all documents in the knowledge base."""
    return vector_service.list_documents()


@router.delete("/{doc_id}")
async def delete_doc(doc_id: str):
    """Delete a document and all its chunks."""
    deleted = vector_service.delete_document(doc_id)
    return {"deleted_chunks": deleted}
