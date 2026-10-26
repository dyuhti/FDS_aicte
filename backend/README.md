# AICTE FDR Portal FastAPI Showcase

This folder contains a standalone Python FastAPI backend showcase for the AICTE
FDR Portal. It is for demonstration purposes only and uses synthetic,
in-memory data.

`BackendService` in
[`app/services/service.py`](app/services/service.py) provides the simulated
submissions, release requests, status, and summary operations used by the API
routes. No request data is persisted.

## Independence and data mode

- FastAPI is not connected to the existing Flutter app.
- Existing Flutter routing, local storage, state, and application workflows
  remain unchanged.
- MongoDB and all other databases are not connected.
- The database mode is `simulated`; no persistent writes or external network
  requests are made.

## Install and run on Windows PowerShell

From the repository root:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload
```

The interactive API documentation is available at
<http://127.0.0.1:8000/docs>. The process health check is available at
<http://127.0.0.1:8000/health>.

## Run tests

Open another terminal in the `backend/` directory and run:

```powershell
python -m pytest
```

## Demonstration endpoints

- `GET /`
- `GET /health`
- `GET /api/v1/status`
- `GET /api/v1/fdr-submissions`
- `GET /api/v1/fdr-submissions/{submission_id}`
- `GET /api/v1/release-requests`
- `GET /api/v1/summary`
