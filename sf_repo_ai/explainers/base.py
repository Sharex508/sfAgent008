from __future__ import annotations

from abc import ABC, abstractmethod
from pathlib import Path
from typing import Any
import sqlite3


class ExplainerAdapter(ABC):
    adapter_name = "generic"

    @abstractmethod
    def explain(self, resolved: dict[str, Any], repo_root: Path, db: sqlite3.Connection) -> dict[str, Any]:
        raise NotImplementedError
