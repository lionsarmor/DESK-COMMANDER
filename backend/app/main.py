"""HTTP entry point for the Desk Commander modular backend."""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI

from . import database
from .modules.status import router as status_router


@asynccontextmanager
async def lifespan(_: FastAPI):
    database.initialize()
    yield


app = FastAPI(
    title="Desk Commander Backend",
    version="0.1.0",
    docs_url=None,
    redoc_url=None,
    lifespan=lifespan,
)
app.include_router(status_router)

