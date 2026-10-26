"""Versioned API routes for the demonstration backend."""

from fastapi import APIRouter, HTTPException, Request

from app.schemas import (
    FDRSubmissionList,
    ReleaseRequestList,
    StatusResponse,
    SubmissionLookupResponse,
    SummaryResponse,
)
from app.services.service import BackendService

router = APIRouter(prefix="/api/v1", tags=["demonstration"])


def get_service(request: Request) -> BackendService:
    return request.app.state.backend_service


@router.get("/status", response_model=StatusResponse)
def get_status(request: Request) -> StatusResponse:
    return get_service(request).get_status()


@router.get("/fdr-submissions", response_model=FDRSubmissionList)
def get_fdr_submissions(request: Request) -> FDRSubmissionList:
    items = get_service(request).get_fdr_submissions()
    return FDRSubmissionList(items=items, count=len(items))


@router.get(
    "/fdr-submissions/{submission_id}", response_model=SubmissionLookupResponse
)
def get_fdr_submission(
    submission_id: str, request: Request
) -> SubmissionLookupResponse:
    submission = get_service(request).get_fdr_submission_by_id(submission_id)
    if submission is None:
        raise HTTPException(status_code=404, detail="FDR submission not found")
    return SubmissionLookupResponse(item=submission)


@router.get("/release-requests", response_model=ReleaseRequestList)
def get_release_requests(request: Request) -> ReleaseRequestList:
    items = get_service(request).get_release_requests()
    return ReleaseRequestList(items=items, count=len(items))


@router.get("/summary", response_model=SummaryResponse)
def get_summary(request: Request) -> SummaryResponse:
    return get_service(request).get_summary()
