"""Safe public health and capability endpoints."""

from fastapi import APIRouter

from ..config import settings


router = APIRouter(tags=["status"])


@router.get("/healthz")
def health() -> dict:
    return {"ok": True, "service": "desk-commander-backend", "version": "0.1.0"}


@router.get("/api/v1/capabilities")
def capabilities() -> dict:
    return {
        "protocol": "RetroWire/1",
        "environment": settings.environment,
        "platforms": ["x16"],
        "modules": {
            "identity": "scaffolded",
            "chat": "scaffolded",
            "mail": "reserved",
            "games": "reserved",
        },
        "retroPort": settings.retro_port,
        "retroPortOpen": False,
    }

