"""In-memory demonstration service for the AICTE FDR portal."""

from app.config import settings
from app.schemas import (
    FDRSubmission,
    ReleaseRequest,
    ServiceInfo,
    StatusResponse,
    SummaryResponse,
)


class BackendService:
    """Provide synthetic portal data without persistence or external services."""

    def __init__(self) -> None:
        self._fdr_submissions = [
            FDRSubmission(
                submission_id="FDR-DEMO-001",
                institution_name="Demo Engineering College",
                academic_year="2025-26",
                amount=1250000.0,
                status="approved",
                submitted_on="2026-04-15",
            ),
            FDRSubmission(
                submission_id="FDR-DEMO-002",
                institution_name="Sample Polytechnic Institute",
                academic_year="2025-26",
                amount=875000.0,
                status="under_review",
                submitted_on="2026-05-02",
            ),
        ]
        self._release_requests = [
            ReleaseRequest(
                request_id="REL-DEMO-001",
                submission_id="FDR-DEMO-001",
                institution_name="Demo Engineering College",
                amount=625000.0,
                status="pending",
                requested_on="2026-05-20",
            ),
            ReleaseRequest(
                request_id="REL-DEMO-002",
                submission_id="FDR-DEMO-002",
                institution_name="Sample Polytechnic Institute",
                amount=400000.0,
                status="released",
                requested_on="2026-05-11",
            ),
        ]

    def get_fdr_submissions(self) -> list[FDRSubmission]:
        return list(self._fdr_submissions)

    def get_fdr_submission_by_id(self, submission_id: str) -> FDRSubmission | None:
        return next(
            (
                submission
                for submission in self._fdr_submissions
                if submission.submission_id == submission_id
            ),
            None,
        )

    def get_release_requests(self) -> list[ReleaseRequest]:
        return list(self._release_requests)

    def get_summary(self) -> SummaryResponse:
        return SummaryResponse(
            total_fdr_submissions=len(self._fdr_submissions),
            total_release_requests=len(self._release_requests),
            approved_submissions=sum(
                submission.status == "approved"
                for submission in self._fdr_submissions
            ),
            pending_release_requests=sum(
                request.status == "pending" for request in self._release_requests
            ),
            total_submitted_amount=sum(
                submission.amount for submission in self._fdr_submissions
            ),
        )

    def get_status(self) -> StatusResponse:
        return StatusResponse(
            service_name=settings.service_name,
            version=settings.api_version,
            environment=settings.environment,
            database_mode=settings.database_mode,
            simulated=True,
            service_status="running",
        )

    def get_service_info(self) -> ServiceInfo:
        return ServiceInfo(
            service_name=settings.service_name,
            version=settings.api_version,
            environment=settings.environment,
            database_mode=settings.database_mode,
            simulated=True,
        )
