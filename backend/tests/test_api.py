"""API tests for the standalone FastAPI showcase."""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_root_returns_service_information() -> None:
    response = client.get("/")

    assert response.status_code == 200
    assert response.json()["simulated"] is True
    assert response.json()["database_mode"] == "simulated"


def test_health_reports_running_process() -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "database_mode": "simulated",
        "simulated": True,
    }


def test_status_endpoint() -> None:
    response = client.get("/api/v1/status")

    assert response.status_code == 200
    assert response.json()["service_status"] == "running"
    assert response.json()["simulated"] is True


def test_fdr_submission_listing() -> None:
    response = client.get("/api/v1/fdr-submissions")

    assert response.status_code == 200
    body = response.json()
    assert body["count"] == 2
    assert body["items"][0]["submission_id"] == "FDR-DEMO-001"
    assert body["simulated"] is True


def test_nonexistent_submission_returns_not_found() -> None:
    response = client.get("/api/v1/fdr-submissions/unknown")

    assert response.status_code == 404


def test_release_request_listing() -> None:
    response = client.get("/api/v1/release-requests")

    assert response.status_code == 200
    assert response.json()["count"] == 2
    assert response.json()["items"][0]["request_id"] == "REL-DEMO-001"


def test_summary_endpoint() -> None:
    response = client.get("/api/v1/summary")

    assert response.status_code == 200
    assert response.json()["total_fdr_submissions"] == 2
    assert response.json()["approved_submissions"] == 1
    assert response.json()["pending_release_requests"] == 1
    assert response.json()["simulated"] is True
