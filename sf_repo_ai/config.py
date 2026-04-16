from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

DEFAULT_REPO_ROOT = "."
DEFAULT_SFDX_ROOT = "force-app/main/default"
DEFAULT_SQLITE_PATH = "data/index.sqlite"
DEFAULT_OLLAMA_BASE_URL = "http://localhost:11434"
DEFAULT_OLLAMA_GEN_MODEL = "gpt-oss:20b"
DEFAULT_OLLAMA_EMBED_MODEL = "all-minilm"
DEFAULT_OLLAMA_TEMPERATURE = 0.2
DEFAULT_OLLAMA_TOP_P = 0.9
DEFAULT_RAG_ENABLED = True
DEFAULT_CHROMA_DIR = "data/chroma"
DEFAULT_RAG_TOP_K = 12
DEFAULT_MAX_EVIDENCE_CHARS = 120000


@dataclass(slots=True)
class OllamaConfig:
    base_url: str = DEFAULT_OLLAMA_BASE_URL
    gen_model: str = DEFAULT_OLLAMA_GEN_MODEL
    embed_model: str = DEFAULT_OLLAMA_EMBED_MODEL
    temperature: float = DEFAULT_OLLAMA_TEMPERATURE
    top_p: float = DEFAULT_OLLAMA_TOP_P


@dataclass(slots=True)
class RagConfig:
    enabled: bool = DEFAULT_RAG_ENABLED
    chroma_dir: str = DEFAULT_CHROMA_DIR
    top_k: int = DEFAULT_RAG_TOP_K
    max_evidence_chars: int = DEFAULT_MAX_EVIDENCE_CHARS


@dataclass(slots=True)
class AppConfig:
    repo_root: str = DEFAULT_REPO_ROOT
    sfdx_root: str = DEFAULT_SFDX_ROOT
    sqlite_path: str = DEFAULT_SQLITE_PATH
    ollama: OllamaConfig = field(default_factory=OllamaConfig)
    rag: RagConfig = field(default_factory=RagConfig)

    def resolve_repo_root(self, project_root: Path | None = None) -> Path:
        root = Path(self.repo_root)
        if not root.is_absolute() and project_root is not None:
            root = project_root / root
        return root.resolve()

    def resolve_sqlite_path(self, project_root: Path | None = None) -> Path:
        p = Path(self.sqlite_path)
        if not p.is_absolute() and project_root is not None:
            p = project_root / p
        return p.resolve()

    def resolve_chroma_dir(self, project_root: Path | None = None) -> Path:
        p = Path(self.rag.chroma_dir)
        if not p.is_absolute() and project_root is not None:
            p = project_root / p
        return p.resolve()


def _load_yaml(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    if not isinstance(data, dict):
        return {}
    return data


def load_config(config_path: str | Path | None = None, *, project_root: Path | None = None) -> AppConfig:
    project_root = project_root or Path.cwd()
    path = Path(config_path) if config_path else (project_root / "config.yaml")
    raw = _load_yaml(path)

    ollama_raw = raw.get("ollama", {}) if isinstance(raw.get("ollama"), dict) else {}
    rag_raw = raw.get("rag", {}) if isinstance(raw.get("rag"), dict) else {}

    cfg = AppConfig(
        repo_root=str(raw.get("repo_root", DEFAULT_REPO_ROOT)),
        sfdx_root=str(raw.get("sfdx_root", DEFAULT_SFDX_ROOT)),
        sqlite_path=str(raw.get("sqlite_path", DEFAULT_SQLITE_PATH)),
        ollama=OllamaConfig(
            base_url=str(ollama_raw.get("base_url", DEFAULT_OLLAMA_BASE_URL)),
            gen_model=str(ollama_raw.get("gen_model", DEFAULT_OLLAMA_GEN_MODEL)),
            embed_model=str(ollama_raw.get("embed_model", DEFAULT_OLLAMA_EMBED_MODEL)),
            temperature=float(ollama_raw.get("temperature", DEFAULT_OLLAMA_TEMPERATURE)),
            top_p=float(ollama_raw.get("top_p", DEFAULT_OLLAMA_TOP_P)),
        ),
        rag=RagConfig(
            enabled=bool(rag_raw.get("enabled", DEFAULT_RAG_ENABLED)),
            chroma_dir=str(rag_raw.get("chroma_dir", DEFAULT_CHROMA_DIR)),
            top_k=int(rag_raw.get("top_k", DEFAULT_RAG_TOP_K)),
            max_evidence_chars=int(rag_raw.get("max_evidence_chars", DEFAULT_MAX_EVIDENCE_CHARS)),
        ),
    )
    return cfg
