"""Environment-only backend configuration.

Production secrets belong in `/etc/deskcommander/backend.env`, never in Git.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    environment: str
    database_path: Path
    bind_host: str
    http_port: int
    retro_port: int


def load_settings() -> Settings:
    return Settings(
        environment=os.getenv("DC_ENV", "development"),
        database_path=Path(os.getenv("DC_DATABASE", "data/deskcommander.sqlite3")),
        bind_host=os.getenv("DC_BIND", "127.0.0.1"),
        http_port=int(os.getenv("DC_HTTP_PORT", "8080")),
        retro_port=int(os.getenv("DC_RETRO_PORT", "6502")),
    )


settings = load_settings()

