from __future__ import annotations

import hashlib
import uuid
from typing import Any

import chromadb
from chromadb.config import Settings as ChromaSettings
from sentence_transformers import SentenceTransformer

from config import get_settings

_client: chromadb.ClientAPI | None = None
_embed_model: SentenceTransformer | None = None


def _get_chroma() -> chromadb.ClientAPI:
    global _client
    if _client is None:
        settings = get_settings()
        _client = chromadb.PersistentClient(
            path=settings.chroma_persist_dir,
            settings=ChromaSettings(anonymized_telemetry=False),
        )
    return _client


def _get_embedder() -> SentenceTransformer:
    global _embed_model
    if _embed_model is None:
        settings = get_settings()
        _embed_model = SentenceTransformer(settings.embedding_model)
    return _embed_model


def _collection():
    return _get_chroma().get_or_create_collection(
        name="knowledge_base",
        metadata={"hnsw:space": "cosine"},
    )


def _chunk_text(text: str, chunk_size: int = 512, overlap: int = 64) -> list[str]:
    """Split text into overlapping chunks by character count."""
    chunks: list[str] = []
    start = 0
    while start < len(text):
        end = start + chunk_size
        chunk = text[start:end].strip()
        if chunk:
            chunks.append(chunk)
        start += chunk_size - overlap
    return chunks


def _embed(texts: list[str]) -> list[list[float]]:
    model = _get_embedder()
    return model.encode(texts, normalize_embeddings=True).tolist()


def add_document(
    title: str,
    content: str,
    metadata: dict[str, Any] | None = None,
) -> tuple[str, int]:
    """Chunk, embed, and store a document. Returns (doc_id, chunk_count)."""
    settings = get_settings()
    doc_id = hashlib.sha256(content.encode()).hexdigest()[:16]
    chunks = _chunk_text(
        content,
        chunk_size=settings.rag_chunk_size,
        overlap=settings.rag_chunk_overlap,
    )
    if not chunks:
        return doc_id, 0

    ids = [f"{doc_id}_{i}" for i in range(len(chunks))]
    embeddings = _embed(chunks)
    metas = [
        {
            "doc_id": doc_id,
            "title": title or "untitled",
            "chunk_idx": i,
            **(metadata or {}),
        }
        for i in range(len(chunks))
    ]

    col = _collection()
    col.upsert(ids=ids, embeddings=embeddings, documents=chunks, metadatas=metas)
    return doc_id, len(chunks)


def query(text: str, top_k: int = 5) -> list[dict]:
    """Return most relevant chunks for a query string."""
    col = _collection()
    if col.count() == 0:
        return []

    embeddings = _embed([text])
    results = col.query(
        query_embeddings=embeddings,
        n_results=min(top_k, col.count()),
        include=["documents", "metadatas", "distances"],
    )

    items: list[dict] = []
    for doc, meta, dist in zip(
        results["documents"][0],
        results["metadatas"][0],
        results["distances"][0],
    ):
        items.append({
            "content": doc,
            "title": meta.get("title", ""),
            "doc_id": meta.get("doc_id", ""),
            "score": 1 - dist,  # cosine similarity
        })
    return items


def list_documents() -> list[dict]:
    """List all unique documents in the store."""
    col = _collection()
    if col.count() == 0:
        return []

    all_data = col.get(include=["metadatas"])
    seen: dict[str, dict] = {}
    for meta in all_data["metadatas"]:
        did = meta.get("doc_id", "unknown")
        if did not in seen:
            seen[did] = {"doc_id": did, "title": meta.get("title", ""), "chunk_count": 0}
        seen[did]["chunk_count"] += 1
    return list(seen.values())


def delete_document(doc_id: str) -> int:
    """Delete all chunks of a document. Returns deleted count."""
    col = _collection()
    all_data = col.get(include=["metadatas"])
    ids_to_delete = [
        id_
        for id_, meta in zip(all_data["ids"], all_data["metadatas"])
        if meta.get("doc_id") == doc_id
    ]
    if ids_to_delete:
        col.delete(ids=ids_to_delete)
    return len(ids_to_delete)
