from __future__ import annotations

import json
from collections.abc import AsyncIterator

import httpx

from config import get_settings


async def chat_completion(
    messages: list[dict],
    system_prompt: str | None = None,
) -> str:
    settings = get_settings()
    body = _build_body(messages, system_prompt, stream=False)

    async with httpx.AsyncClient(timeout=180) as client:
        resp = await client.post(
            settings.llm_base_url,
            json=body,
            headers=_headers(),
        )
        resp.raise_for_status()
        data = resp.json()
        return _extract_content(data)


async def chat_completion_stream(
    messages: list[dict],
    system_prompt: str | None = None,
) -> AsyncIterator[str]:
    """Yield raw SSE lines forwarded from the upstream LLM."""
    settings = get_settings()
    body = _build_body(messages, system_prompt, stream=True)

    async with httpx.AsyncClient(timeout=180) as client:
        async with client.stream(
            "POST",
            settings.llm_base_url,
            json=body,
            headers=_headers(),
        ) as resp:
            resp.raise_for_status()
            async for line in resp.aiter_lines():
                if line.strip():
                    yield line


def _build_body(
    messages: list[dict],
    system_prompt: str | None,
    *,
    stream: bool,
) -> dict:
    settings = get_settings()
    msgs: list[dict] = []
    if system_prompt:
        msgs.append({"role": "system", "content": system_prompt})
    msgs.extend(messages)
    return {"model": settings.llm_model, "messages": msgs, "stream": stream}


def _headers() -> dict[str, str]:
    settings = get_settings()
    return {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {settings.llm_api_key}",
    }


def _extract_content(data: dict) -> str:
    try:
        return data["choices"][0]["message"]["content"]
    except (KeyError, IndexError):
        return json.dumps(data, ensure_ascii=False)
