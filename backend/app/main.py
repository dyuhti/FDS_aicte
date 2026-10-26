"""Application entry point for the standalone FastAPI showcase."""

from fastapi import FastAPI

from app.api.routes import router
from app.config import settings
from app.services.service import BackendService

app = FastAPI(
    title=settings.service_name,
    version=settings.api_version,
    description=(
        "A standalone, simulated FastAPI showcase for the AICTE FDR Portal. "
        "It is not connected to the Flutter application or a database."
    ),
)
app.state.backend_service = BackendService()
app.include_router(router)


@app.get("/", tags=["service"])
def get_service_info():
    return app.state.backend_service.get_service_info()


@app.get("/health", tags=["service"])
def get_health():
    return {
        "status": "ok",
        "database_mode": settings.database_mode,
        "simulated": True,
    }
