from __future__ import annotations

from ddgs import DDGS

from config import get_settings
from services import llm_service, vector_service


async def rag_query(
    question: str,
    context: str | None = None,
    *,
    use_web_search: bool = True,
    use_local_kb: bool = True,
    top_k: int = 5,
) -> dict:
    """
    Dual-source RAG: local vector store + web search.
    Returns {"answer": str, "sources": list[dict]}.
    """
    sources: list[dict] = []
    reference_blocks: list[str] = []

    # ── 1. Local knowledge base (ChromaDB) ───────
    if use_local_kb:
        local_hits = vector_service.query(question, top_k=top_k)
        for hit in local_hits:
            sources.append({
                "title": hit["title"],
                "snippet": hit["content"][:200],
                "url": None,
                "source_type": "local",
            })
            reference_blocks.append(
                f"[本地知识库 - {hit['title']}]\n{hit['content']}"
            )

    # ── 2. Web search (DuckDuckGo) ───────────────
    if use_web_search:
        settings = get_settings()
        try:
            with DDGS() as ddgs:
                results = list(
                    ddgs.text(question, max_results=settings.web_search_max_results)
                )
            for r in results:
                sources.append({
                    "title": r.get("title", ""),
                    "snippet": r.get("body", "")[:200],
                    "url": r.get("href"),
                    "source_type": "web",
                })
                reference_blocks.append(
                    f"[网络搜索 - {r.get('title', '')}]\n{r.get('body', '')}"
                )
        except Exception:
            pass  # web search failure is non-fatal

    # ── 3. Build augmented prompt ────────────────
    ref_text = "\n\n---\n\n".join(reference_blocks) if reference_blocks else ""

    system_prompt = (
        "你是一个智能学习助手。请根据下面提供的参考资料回答用户的问题。\n"
        "如果参考资料中有相关信息，请优先引用；如果没有，请基于你自己的知识回答。\n"
        "回答要准确、详细、条理清晰。"
    )

    user_content = question
    if context:
        user_content = f"背景信息：{context}\n\n问题：{question}"

    messages = [{"role": "user", "content": user_content}]

    if ref_text:
        system_prompt += f"\n\n## 参考资料\n\n{ref_text}"

    answer = await llm_service.chat_completion(messages, system_prompt=system_prompt)

    return {"answer": answer, "sources": sources}
