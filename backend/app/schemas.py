"""Pydantic schemas exposed by the demonstration API."""

from pydantic import BaseModel, ConfigDict


class ServiceInfo(BaseModel):
    service_name: str
    version: str
    environment: str
    database_mode: str
    simulated: bool


class HealthResponse(BaseModel):
    status: str
    database_mode: str
    simulated: bool


class FDRSubmission(BaseModel):
    model_config = ConfigDict(frozen=True)

    submission_id: str
    institution_name: str
    academic_year: str
    amount: float
    status: str
    submitted_on: str
    simulated: bool = True


class ReleaseRequest(BaseModel):
    model_config = ConfigDict(frozen=True)

    request_id: str
    submission_id: str
    institution_name: str
    amount: float
    status: str
    requested_on: str
    simulated: bool = True


class FDRSubmissionList(BaseModel):
    items: list[FDRSubmission]
    count: int
    simulated: bool = True


class ReleaseRequestList(BaseModel):
    items: list[ReleaseRequest]
    count: int
    simulated: bool = True


class SummaryResponse(BaseModel):
    total_fdr_submissions: int
    total_release_requests: int
    approved_submissions: int
    pending_release_requests: int
    total_submitted_amount: float
    simulated: bool = True


class StatusResponse(ServiceInfo):
    service_status: str


class SubmissionLookupResponse(BaseModel):
    item: FDRSubmission
    simulated: bool = True
