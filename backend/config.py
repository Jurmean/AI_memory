from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # LLM
    llm_base_url: str = "https://api.minimaxi.com/v1/chat/completions"
    llm_model: str = "MiniMax-M2.7"
    llm_api_key: str = ""

    # ChromaDB
    chroma_persist_dir: str = "./chroma_data"

    # Embedding (sentence-transformers model, downloaded on first use)
    embedding_model: str = "BAAI/bge-small-zh-v1.5"

    # Web search
    web_search_max_results: int = 5

    # RAG
    rag_top_k: int = 5
    rag_chunk_size: int = 512
    rag_chunk_overlap: int = 64

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
