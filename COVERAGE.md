# Feature Coverage

This map points to the implementation and automated regression tests currently in the repository. Existing workflow tests remain in `test/release_case_test.dart`, `test/institution_dashboard_test.dart`, `test/notification_center_test.dart`, and `test/widget_test.dart`; new focused coverage is in `test/phase_coverage_test.dart` and the deterministic seed test in `test/f1_f5_feature_test.dart`.

## F1: Verification and Discrepancies

- Four-source comparison for all nine requested fields, status/differing source data, and distinct institution/trust rules: `lib/officer_dashboard.dart` (`FdrVerificationService`, `FieldComparison`); `phase_coverage_test.dart` comparison test checks all four source keys and mismatch rules.
- Configurable amount tolerance and enabled rules affecting verification: `lib/officer_dashboard.dart` (`RuleConfig`, `FdrVerificationService`); `phase_coverage_test.dart` rule-config test.
- Discrepancy history transitions through open, resolved, reopened and warning-only waiver: `lib/officer_dashboard.dart` (`reconcileDiscrepancies`, `waiveDiscrepancy`); `phase_coverage_test.dart` lifecycle test.

## F2: Release Cases and Documents

- Formal case statuses, allowed transition map, illegal transition exception, audit writes, and ready-for-NOC eligibility guard: `lib/officer_dashboard.dart` (`ALLOWED_TRANSITIONS`, `validateCaseTransition`, `DemoFdrPortalStore.transition`); `phase_coverage_test.dart` transition matrix and guard tests. Existing release tests cover missing documents, unresolved discrepancies, and pending clearances independently.
- File type/MIME/size validation, byte checksum, versions, persistent bytes, and tamper detection: `lib/officer_dashboard.dart` (`validateDocumentUpload`, `uploadRequiredDocumentBytes`, `verifyDocumentIntegrity`); `phase_coverage_test.dart` upload test.
- Officer and institution case history UI: `lib/officer_dashboard.dart`, `lib/institution_dashboard.dart`; existing institution and release workflow widget tests.

## F3: Deadlines and Renewals

- Clock-relative Critical (six days), Active, Expiring Soon, Matured, exactly one labeled invalid-date record, and child lineage: `lib/officer_dashboard.dart` (`resetDemoData`, `seedDemoCases`, `createRenewal`); `f1_f5_feature_test.dart` F6 seed test and `phase_coverage_test.dart` renewal tests.
- Renewal validation, parent renewal state, action-queue removal, and lineage: `phase_coverage_test.dart` renewal tests.
- Reminder idempotence after storage reload: `phase_coverage_test.dart` reminder restart test; `test/f1_f5_feature_test.dart` retains legacy duplicate-scan coverage.
- Institution-scoped submission data: `lib/institution_dashboard.dart`; `phase_coverage_test.dart` institution scope test.

## F4: Audit and Access

- Persisted chain and tail anchor; tampering and truncation reason/index: `lib/officer_dashboard.dart` (`initializeAuditPersistence`, `verifyPersistedAuditChain`, `tamperPersistedAuditRecord`); `phase_coverage_test.dart` persistence/tamper/truncation test.
- Document byte restoration and tamper detection: `phase_coverage_test.dart` upload persistence test.
- Permission action/role matrix, HMAC token signature and expiry: `lib/portal_foundations.dart`; `phase_coverage_test.dart` role-matrix and token tests.
- Existing audit hash-chain behavior remains covered in `test/release_case_test.dart` and `test/f1_f5_feature_test.dart`.

## F5: Queue, Risk, Reports, and Export

- Queue dedupe, merged reasons/categories, target resolution: `lib/officer_dashboard.dart` (`buildOfficerActionQueue`, `queueTargetFor`); `phase_coverage_test.dart` queue test. The compact widget test traverses queue to a release case.
- Weighted risk reasons and score reconciliation: `lib/officer_dashboard.dart` (`riskWeights`, `assessInstitutionRisk`); `phase_coverage_test.dart` risk test.
- CSV delimiters, quoting, formula neutralization, and physical file creation: `lib/officer_dashboard.dart` (`_csvCell`, CSV builders, `writeCsvFile`); `phase_coverage_test.dart` CSV test.
- Reports aggregation reconciliation: `ReportsRepository` / `StoreReportsRepository` in `lib/officer_dashboard.dart`; `phase_coverage_test.dart` reports totals test.

## Responsive Widgets

- Queue, release case, and Demo Script bottom navigation and overflow at 360×640 with text scale 1.3: `phase_coverage_test.dart` compact widget test.

## Honest Limitations

- Persistence is local to the device/browser through SharedPreferences-backed storage; it is not synchronized across users or devices.
- Authentication is a local demo implementation with an embedded demo signing secret. It is not suitable for production identity or authorization.
- There is no backend service, server-side audit anchor, or authoritative remote clock; local storage can be modified by a user with access to the device/browser profile.
- CSV sharing uses the platform share sheet and clipboard fallback. Browser download behavior and native share targets vary by platform.
- The transition map is exhaustively tested for legal/illegal pairs, while the store-level audit assertion exercises representative legal transitions; full independent role-driven workflow testing for every transition pair remains a useful extension.
