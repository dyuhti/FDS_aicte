"""Configuration for the standalone demonstration backend."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    service_name: str = os.getenv(
        "BACKEND_SERVICE_NAME", "AICTE FDR Portal Backend Showcase"
    )
    api_version: str = os.getenv("BACKEND_API_VERSION", "v1")
    environment: str = os.getenv("BACKEND_ENVIRONMENT", "demo")
    database_mode: str = os.getenv("BACKEND_DATABASE_MODE", "simulated")


settings = Settings()
