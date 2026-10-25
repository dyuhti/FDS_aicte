import 'package:fds_aicte/main.dart';
import 'package:fds_aicte/officer_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _passedVerification = VerificationSummary(
  totalChecks: 1,
  blocking: 0,
  warnings: 1,
  statusText: 'PASSED — No Blocking Discrepancies',
  issues: [
    VerificationIssue(
      ruleId: 'lien-information',
      severity: VerificationIssueSeverity.warning,
      message: 'Lien information requires review.',
    ),
  ],
);

const _blockedVerification = VerificationSummary(
  totalChecks: 1,
  blocking: 1,
  warnings: 0,
  statusText: 'BLOCKED — 1 Blocking Discrepancy',
  issues: [
    VerificationIssue(
      ruleId: 'deposit-amount',
      severity: VerificationIssueSeverity.blocking,
      message: 'Declared amount does not match.',
    ),
  ],
);

const _presentDocuments = [
  DemoChecklistItem(
    name: 'Request Letter',
    fileName: 'request_letter.pdf',
    status: 'Present — Demo',
  ),
];

const _clearedCells = [
  ClearanceState(
    name: 'Grievance Redressal Cell',
    status: 'Cleared',
    remark: 'Reviewed',
    actionRequired: 'Review grievances.',
  ),
  ClearanceState(
    name: 'Vigilance Cell',
    status: 'Cleared',
    remark: 'Reviewed',
    actionRequired: 'Review compliance.',
  ),
];

void main() {
  group('Officer dashboard data', () {
    final store = DemoFdrPortalStore.instance;
    const repository = MockOfficerDashboardRepository();

    setUp(store.resetDemoData);

    test('passed FDR verification remains pending until explicit approval', () {
      expect(repository.summary, {
        'Pending Review': 4,
        'Approved': 0,
        'Rejected': 0,
        'Needs Correction': 1,
        'Blocked': 1,
        'Total Submissions': 6,
        'Total Institutions': 3,
      });
      expect(
        store.dashboardSubmissions.map((submission) => submission.submissionId),
        containsAll(['FDR-2026-00124', 'FDR-2026-00125', 'FDR-2026-00126']),
      );

      store.setCurrentSubmission(
        store.currentSubmission.copyWith(
          fdrNumber: 'FDR-UNIQUE-DASHBOARD-001',
          declaredDepositAmount: 450000,
        ),
      );
      final verification = store.runCurrentVerification();

      expect(verification.blocking, 0);
      expect(
        store.currentSubmission.submissionStatus,
        'FDR Verified — Awaiting Officer Approval',
      );
      expect(repository.summary['Pending Review'], 4);
      expect(repository.summary['Approved'], 0);
      expect(repository.summary['Needs Correction'], 1);
      expect(repository.summary['Total Institutions'], 3);
      expect(
        repository.pendingSubmissions.map(
          (submission) => submission.submissionId,
        ),
        contains('FDR-2026-00124'),
      );
      expect(
        store.dashboardSubmissions
            .singleWhere(
              (submission) => submission.submissionId == 'FDR-2026-00124',
            )
            .status,
        VerificationStatus.pending,
      );
    });

    test('blocked submission leaves pending and appears in blocked status', () {
      store.runCurrentVerification();

      expect(repository.summary['Pending Review'], 3);
      expect(repository.summary['Needs Correction'], 1);
      expect(
        store.currentSubmission.submissionStatus,
        'Blocked — FDR Verification',
      );
      expect(
        store.dashboardSubmissions
            .singleWhere(
              (submission) => submission.submissionId == 'FDR-2026-00124',
            )
            .status,
        VerificationStatus.blocked,
      );
      expect(
        repository
            .submissionsByStatus(SubmissionStatus.blocked)
            .map((submission) => submission.submissionId),
        contains('FDR-2026-00124'),
      );
    });

    test('Final NOC does not mark the submission officially approved', () {
      store.setCurrentSubmission(
        store.currentSubmission.copyWith(
          fdrNumber: 'FDR-UNIQUE-DASHBOARD-002',
          declaredDepositAmount: 450000,
        ),
      );
      store.createReleaseCase();
      store.runCurrentVerification();

      expect(repository.summary['Pending Review'], 4);
      expect(repository.summary['Approved'], 0);
      store.updateClearanceStatus('Grievance Redressal Cell', 'Cleared');
      store.updateClearanceStatus('Vigilance Cell', 'Cleared');
      expect(repository.summary['Approved'], 0);

      store.issueDemoNoc();

      expect(store.releaseCase!.status, 'NOC Issued — Demo');
      expect(repository.summary['Approved'], 0);
      expect(repository.summary['Needs Correction'], 1);
    });

    test(
      'eligible demo merger approval updates the linked submission once',
      () {
        store.createReleaseCase();
        store.updateReleaseCaseType('Merger');
        store.setLastVerification(_passedVerification);
        store.updateClearanceStatus('Grievance Redressal Cell', 'Cleared');
        store.updateClearanceStatus('Vigilance Cell', 'Cleared');
        store.approveMergerInDemoMode();

        final approved = store.dashboardSubmissions.singleWhere(
          (submission) => submission.submissionId == 'FDR-2026-00124',
        );
        expect(approved.status, VerificationStatus.approved);
        expect(approved.approvedAt, isNotNull);
        expect(approved.approvedBy, 'Demo Officer');
        expect(repository.summary['Approved'], 1);
        expect(
          repository.summary['Approved'],
          repository.submissions
              .where(
                (submission) =>
                    submission.status == VerificationStatus.approved,
              )
              .length,
        );
        expect(store.currentSubmission.submissionStatus, 'Approved — Demo');
        expect(
          repository.pendingSubmissions.map(
            (submission) => submission.submissionId,
          ),
          isNot(contains('FDR-2026-00124')),
        );

        store.approveMergerInDemoMode();
        expect(repository.summary['Approved'], 1);
      },
    );

    test(
      'updating an existing institution does not increase registry count',
      () {
        final initialCount = repository.summary['Total Institutions'];

        store.setCurrentSubmission(
          store.currentSubmission.copyWith(
            institution: 'Example Institute of Technology, Updated',
          ),
        );

        expect(repository.summary['Total Institutions'], initialCount);
      },
    );
  });

  group('Submission selectors', () {
    const records = [
      Submission(
        institution: 'Example Institute',
        institutionId: 'INST-1',
        submissionId: 'FDR-2026-00001',
        submittedOn: '24 Oct 2026',
        reference: 'FDR-1',
        amount: '₹100,000',
        status: SubmissionStatus.correctionRequested,
      ),
      Submission(
        institution: 'Example Institute',
        institutionId: 'INST-1',
        submissionId: 'FDR-2026-00002',
        submittedOn: '23 Oct 2026',
        reference: 'FDR-2',
        amount: '₹200,000',
        status: SubmissionStatus.blocked,
      ),
      Submission(
        institution: 'National College',
        institutionId: 'INST-2',
        submissionId: 'FDR-2026-00003',
        submittedOn: '22 Oct 2026',
        reference: 'FDR-3',
        amount: '₹300,000',
        status: SubmissionStatus.pendingReview,
      ),
    ];

    test('all selectors derive counts and groups from the same records', () {
      expect(countByStatus(records, SubmissionStatus.pendingReview), 1);
      expect(countByStatus(records, SubmissionStatus.approved), 0);
      expect(countByStatus(records, SubmissionStatus.rejected), 0);
      expect(countByStatus(records, SubmissionStatus.correctionRequested), 1);
      expect(countByStatus(records, SubmissionStatus.blocked), 1);
      expect(totalSubmissions(records), 3);
      expect(uniqueInstitutionCount(records), 2);
      expect(
        submissionsByStatus(records, SubmissionStatus.blocked).single.id,
        'FDR-2026-00002',
      );
      expect(groupedByInstitution(records)['INST-1'], hasLength(2));
    });

    test('status counts sum to total and repeated institutions count once', () {
      final statusTotal = SubmissionStatus.values.fold<int>(
        0,
        (sum, status) => sum + countByStatus(records, status),
      );
      expect(statusTotal, totalSubmissions(records));
      expect(uniqueInstitutionCount(records), 2);
      expect(
        records.map((record) => record.id).toSet(),
        hasLength(records.length),
      );
      expect(
        SubmissionStatus.values.fold<int>(
          0,
          (sum, status) => sum + submissionsByStatus(records, status).length,
        ),
        records.length,
      );
    });

    test('canonical fields preserve a normalized updated timestamp', () {
      final updatedAt = DateTime.utc(2026, 10, 25);
      final record = Submission.fromFields(
        id: 'FDR-2026-00130',
        institutionId: 'INST-3',
        institutionName: 'Demo Institute',
        fdrReference: 'FDR-3',
        bank: 'Demo Bank',
        caseType: 'FDR Submission',
        depositAmount: 400000,
        status: SubmissionStatus.pendingReview,
        updatedAt: updatedAt,
      );

      expect(record.id, 'FDR-2026-00130');
      expect(record.institutionName, 'Demo Institute');
      expect(record.fdrReference, 'FDR-3');
      expect(record.bank, 'Demo Bank');
      expect(record.depositAmount, 400000);
      expect(record.updatedAt, updatedAt);
    });

    test('seeded submission IDs are unique and normalized', () {
      DemoFdrPortalStore.instance.resetDemoData();
      final ids = DemoFdrPortalStore.instance.dashboardSubmissions
          .map((record) => record.id)
          .toList();

      expect(ids.toSet(), hasLength(ids.length));
      expect(
        ids.every((id) => RegExp(r'^FDR-\d{4}-\d{5}$').hasMatch(id)),
        isTrue,
      );
    });
  });

  group('canAdvanceReleaseCase', () {
    test('blocks unresolved discrepancies and keeps warnings visible', () {
      final result = canAdvanceReleaseCase(
        _blockedVerification,
        _presentDocuments,
        _clearedCells,
      );

      expect(result.canAdvance, isFalse);
      expect(result.nextEligibleStage, 'FDR Verification');
      expect(result.blockingReasons, hasLength(1));
    });

    test('blocks a missing required document', () {
      const missingDocuments = [
        DemoChecklistItem(
          name: 'Request Letter',
          fileName: 'request_letter.pdf',
          isPresent: false,
          status: 'Missing — Demo',
        ),
      ];

      final result = canAdvanceReleaseCase(
        _passedVerification,
        missingDocuments,
        _clearedCells,
      );

      expect(result.canAdvance, isFalse);
      expect(result.nextEligibleStage, 'Required Documents');
      expect(result.blockingReasons.single, contains('Request Letter'));
    });

    test('treats cell decisions independently and permits warnings', () {
      const oneCellPending = [
        ClearanceState(
          name: 'Grievance Redressal Cell',
          status: 'Cleared',
          remark: 'Reviewed',
          actionRequired: 'Review grievances.',
        ),
        ClearanceState(
          name: 'Vigilance Cell',
          status: 'Clarification Requested',
          remark: 'Need details',
          actionRequired: 'Review compliance.',
        ),
      ];

      final blocked = canAdvanceReleaseCase(
        _passedVerification,
        _presentDocuments,
        oneCellPending,
      );
      final eligible = canAdvanceReleaseCase(
        _passedVerification,
        _presentDocuments,
        _clearedCells,
      );

      expect(blocked.canAdvance, isFalse);
      expect(blocked.nextEligibleStage, 'Cell Clearances');
      expect(eligible.canAdvance, isTrue);
      expect(eligible.nextEligibleStage, 'Final NOC');
      expect(eligible.warnings, contains('Lien information requires review.'));
    });
  });

  group('ReleaseEligibilityService', () {
    test('validates progressive release amount and retained balance', () {
      final store = DemoFdrPortalStore.instance;
      store.resetDemoData();
      store.createReleaseCase();
      store.updateReleaseCaseType('Progressive Closure');
      final progressiveCase = store.releaseCase!;

      expect(progressiveCase.caseId, 'PCL-2026-00008');
      expect(progressiveCase.retainedBalance, 350000);
      final eligible = ReleaseEligibilityService.evaluate(
        record: progressiveCase.copyWith(clearances: _clearedCells),
        verification: _passedVerification,
      );
      expect(eligible.canAdvance, isTrue);

      final invalid = ReleaseEligibilityService.evaluate(
        record: progressiveCase.copyWith(
          requestedReleaseAmount: 600000,
          clearances: _clearedCells,
        ),
        verification: _passedVerification,
      );
      expect(invalid.canAdvance, isFalse);
      expect(
        invalid.blockingReasons.join(' '),
        contains('original FDR amount'),
      );
      expect(invalid.blockingReasons.join(' '), contains('cannot exceed'));
      expect(invalid.blockingReasons.join(' '), contains('negative'));
    });

    test(
      'requires merger details, supporting documents, and independent clearances',
      () {
        final store = DemoFdrPortalStore.instance;
        store.resetDemoData();
        store.createReleaseCase();
        store.updateReleaseCaseType('Merger');
        final mergerCase = store.releaseCase!;
        expect(mergerCase.caseId, 'MRG-2026-00004');

        final missingDocument = mergerCase.checklist.first.copyWith(
          isPresent: false,
          status: 'Missing — Demo',
        );
        final blocked = ReleaseEligibilityService.evaluate(
          record: mergerCase.copyWith(
            successorInstitution: '',
            mergerReference: '',
            effectiveDate: '',
            checklist: [missingDocument, ...mergerCase.checklist.skip(1)],
          ),
          verification: _passedVerification,
        );
        expect(blocked.canAdvance, isFalse);
        expect(blocked.missingDocuments, contains(missingDocument.name));
        expect(blocked.pendingClearances, contains('Grievance Redressal Cell'));
        expect(
          blocked.blockingReasons.join(' '),
          contains('Successor institution'),
        );
        expect(blocked.blockingReasons.join(' '), contains('Merger reference'));
        expect(blocked.blockingReasons.join(' '), contains('Effective date'));

        final missingFdr = ReleaseEligibilityService.evaluate(
          record: mergerCase.copyWith(clearances: _clearedCells),
          verification: _passedVerification,
          originalFdrExists: false,
        );
        expect(
          missingFdr.blockingReasons,
          contains('The original FDR record could not be verified.'),
        );
      },
    );

    test('keeps each case type state separate while switching', () {
      final store = DemoFdrPortalStore.instance;
      store.resetDemoData();
      store.createReleaseCase();
      store.updateReleaseCaseType('Progressive Closure');
      store.updateProgressiveClosure(
        requestedAmount: 225000,
        reason: 'Updated staged need',
      );
      store.updateReleaseCaseType('Merger');
      store.updateMergerDetails(
        successorInstitution: 'Successor Demo University',
      );
      expect(store.releaseCase!.caseType, 'Merger');
      expect(
        store.releaseCase!.successorInstitution,
        'Successor Demo University',
      );

      store.updateReleaseCaseType('Progressive Closure');
      expect(store.releaseCase!.requestedReleaseAmount, 225000);
      expect(store.releaseCase!.partialReleaseReason, 'Updated staged need');
    });

    test(
      'merger demo approval records a relationship without changing the FDR master',
      () {
        final store = DemoFdrPortalStore.instance;
        store.resetDemoData();
        store.createReleaseCase();
        store.updateReleaseCaseType('Merger');
        final original = store.demoFdrRecords['FDR-MRG-330812']!;
        store.setLastVerification(_passedVerification);
        store.updateClearanceStatus(
          'Grievance Redressal Cell',
          'Cleared',
          remark: 'Demo review complete',
        );
        store.updateClearanceStatus(
          'Vigilance Cell',
          'Cleared',
          remark: 'Demo review complete',
        );

        store.approveMergerInDemoMode();

        expect(store.releaseCase!.status, 'Merger Approved — Demo');
        expect(
          store.mergerRelationships['FDR-MRG-330812'],
          'Example Technical University',
        );
        expect(store.demoFdrRecords['FDR-MRG-330812']!.amount, original.amount);
        expect(
          store.demoFdrRecords['FDR-MRG-330812']!.institution,
          original.institution,
        );
      },
    );
  });

  test(
    'shared verification reports amount mismatch and duplicate FDR blockers',
    () {
      final result = FdrVerificationService.runVerification(
        DemoFdrPortalStore.instance.currentSubmission,
      );

      expect(result.blocking, 2);
      expect(
        result.issues.map((issue) => issue.ruleId),
        containsAll(['deposit-amount', 'duplicate-fdr']),
      );
    },
  );

  test(
    'normal release NOC is gated by verification and repeat calls are idempotent',
    () {
      final store = DemoFdrPortalStore.instance;
      store.resetDemoData();
      store.createReleaseCase();
      store.updateClearanceStatus('Grievance Redressal Cell', 'Cleared');
      store.updateClearanceStatus('Vigilance Cell', 'Cleared');

      store.issueDemoNoc();
      expect(store.releaseCase!.status, isNot('NOC Issued — Demo'));

      store.setVerificationScenario(DemoVerificationScenario.resolved);
      store.issueDemoNoc();
      expect(store.releaseCase!.status, 'NOC Issued — Demo');

      store.issueDemoNoc();
      expect(store.releaseCase!.status, 'NOC Issued — Demo');
    },
  );

  test('cell clearance in one case does not clear another case', () {
    final store = DemoFdrPortalStore.instance;
    store.resetDemoData();
    store.createReleaseCase();
    store.updateClearanceStatus('Grievance Redressal Cell', 'Cleared');
    store.updateReleaseCaseType('Progressive Closure');

    expect(
      store.releaseCase!.clearances
          .where((clearance) => clearance.name == 'Grievance Redressal Cell')
          .single
          .status,
      'Pending',
    );
  });

  group('Normal Release status and eligibility', () {
    final store = DemoFdrPortalStore.instance;

    setUp(() {
      store.resetDemoData();
      store.createReleaseCase();
    });

    test(
      'two verification blockers keep FDR Verification current after both cells clear',
      () {
        store.updateClearanceStatus('Grievance Redressal Cell', 'Cleared');
        store.updateClearanceStatus('Vigilance Cell', 'Cleared');

        expect(store.lastVerification.blocking, 2);
        expect(store.releaseCase!.status, 'Blocked — FDR Verification');
        final eligibility = ReleaseEligibilityService.evaluate(
          record: store.releaseCase!,
          verification: store.lastVerification,
        );
        expect(eligibility.canAdvance, isFalse);
        expect(eligibility.nextEligibleStage, 'FDR Verification');
        store.issueDemoNoc();
        expect(store.releaseCase!.status, 'Blocked — FDR Verification');
      },
    );

    test('correcting one discrepancy leaves the other blocker current', () {
      store.setCurrentSubmission(
        store.currentSubmission.copyWith(declaredDepositAmount: 450000),
      );
      expect(store.verificationCurrent, isFalse);
      expect(store.releaseCase!.status, 'Verification Required');
      store.runCurrentVerification();

      expect(store.currentSubmission.receiptAmount, 450000);
      expect(store.lastVerification.blocking, 1);
      expect(
        store.lastVerification.issues.map((issue) => issue.ruleId),
        contains('duplicate-fdr'),
      );
      expect(store.releaseCase!.status, 'Blocked — FDR Verification');
      expect(
        ReleaseEligibilityService.evaluate(
          record: store.releaseCase!,
          verification: store.lastVerification,
        ).nextEligibleStage,
        'FDR Verification',
      );
    });

    test('resolving both blockers advances status and permits demo NOC', () {
      store.setCurrentSubmission(
        store.currentSubmission.copyWith(
          fdrNumber: 'FDR-EX-884201-CORRECTED',
          declaredDepositAmount: 450000,
        ),
      );
      store.runCurrentVerification();

      expect(store.lastVerification.blocking, 0);
      expect(store.lastVerification.warnings, 1);
      expect(store.releaseCase!.status, 'Awaiting Clearances');

      store.updateClearanceStatus('Grievance Redressal Cell', 'Cleared');
      store.updateClearanceStatus('Vigilance Cell', 'Cleared');

      expect(store.releaseCase!.status, 'Ready for Final NOC');
      expect(
        ReleaseEligibilityService.evaluate(
          record: store.releaseCase!,
          verification: store.lastVerification,
        ).canAdvance,
        isTrue,
      );
      store.issueDemoNoc();
      expect(store.releaseCase!.status, 'NOC Issued — Demo');
    });

    test(
      'missing required document blocks an otherwise clear Normal Release',
      () {
        store.setCurrentSubmission(
          store.currentSubmission.copyWith(
            fdrNumber: 'FDR-UNIQUE-001',
            declaredDepositAmount: 450000,
          ),
        );
        store.runCurrentVerification();
        store.updateClearanceStatus('Grievance Redressal Cell', 'Cleared');
        store.updateClearanceStatus('Vigilance Cell', 'Cleared');
        store.updateDocumentPresence('request_letter.pdf', false);

        expect(store.releaseCase!.status, 'Awaiting Required Documents');
        expect(
          ReleaseEligibilityService.evaluate(
            record: store.releaseCase!,
            verification: store.lastVerification,
          ).missingDocuments,
          contains('Request Letter'),
        );
        store.issueDemoNoc();
        expect(store.releaseCase!.status, 'Awaiting Required Documents');
      },
    );

    test(
      'pending cell clearances advance independently after verification passes',
      () {
        store.setCurrentSubmission(
          store.currentSubmission.copyWith(
            fdrNumber: 'FDR-UNIQUE-002',
            declaredDepositAmount: 450000,
          ),
        );
        store.runCurrentVerification();

        expect(store.releaseCase!.status, 'Awaiting Clearances');
        store.updateClearanceStatus('Grievance Redressal Cell', 'Cleared');
        expect(store.releaseCase!.status, 'Awaiting Clearances');
        expect(
          ReleaseEligibilityService.evaluate(
            record: store.releaseCase!,
            verification: store.lastVerification,
          ).pendingClearances,
          ['Vigilance Cell'],
        );

        store.updateClearanceStatus('Vigilance Cell', 'Cleared');
        expect(store.releaseCase!.status, 'Ready for Final NOC');
      },
    );

    test('missing lien remains a warning and does not block eligibility', () {
      store.setCurrentSubmission(
        store.currentSubmission.copyWith(
          fdrNumber: 'FDR-UNIQUE-003',
          declaredDepositAmount: 450000,
        ),
      );
      store.runCurrentVerification();
      store.updateClearanceStatus('Grievance Redressal Cell', 'Cleared');
      store.updateClearanceStatus('Vigilance Cell', 'Cleared');

      final eligibility = ReleaseEligibilityService.evaluate(
        record: store.releaseCase!,
        verification: store.lastVerification,
      );
      expect(store.lastVerification.blocking, 0);
      expect(store.lastVerification.warnings, 1);
      expect(eligibility.canAdvance, isTrue);
      expect(
        eligibility.warnings,
        contains('Lien information requires review.'),
      );
      expect(store.releaseCase!.status, 'Ready for Final NOC');
    });
  });

  test(
    'saved correction persists to selected submission and verification uses saved fields',
    () {
      final store = DemoFdrPortalStore.instance;
      store.resetDemoData();
      store.createReleaseCase();
      final originalReceipt = store.currentSubmission.receiptAmount;
      final corrected = store.currentSubmission.copyWith(
        fdrNumber: 'FDR-EX-884201-CORRECTED',
        declaredDepositAmount: 450000,
      );

      store.setCurrentSubmission(corrected);

      expect(store.currentSubmission.submissionId, 'FDR-2026-00124');
      expect(
        store.releaseCase!.submissionId,
        store.currentSubmission.submissionId,
      );
      expect(store.currentSubmission.fdrNumber, 'FDR-EX-884201-CORRECTED');
      expect(store.currentSubmission.declaredDepositAmount, 450000);
      expect(store.currentSubmission.receiptAmount, originalReceipt);
      expect(store.verificationCurrent, isFalse);
      expect(
        store.verificationResults.statusText,
        'NOT RUN — Verify saved FDR details',
      );
      expect(store.releaseCase!.status, 'Verification Required');

      final refreshed = store.runCurrentVerification();
      expect(store.verificationCurrent, isTrue);
      expect(refreshed.blocking, 0);
      expect(
        refreshed.issues.map((issue) => issue.ruleId),
        contains('lien-information'),
      );
      expect(store.releaseCase!.status, 'Awaiting Clearances');
    },
  );

  test('saved mismatch or duplicate remains blocked after verification', () {
    final store = DemoFdrPortalStore.instance;
    store.resetDemoData();
    store.createReleaseCase();
    store.setCurrentSubmission(
      store.currentSubmission.copyWith(declaredDepositAmount: 400000),
    );
    expect(store.verificationCurrent, isFalse);
    expect(store.releaseCase!.status, 'Verification Required');

    final summary = store.runCurrentVerification();
    expect(
      summary.issues.map((issue) => issue.ruleId),
      containsAll(['deposit-amount', 'duplicate-fdr']),
    );
    expect(summary.blocking, 2);
    expect(store.releaseCase!.status, 'Blocked — FDR Verification');
  });

  testWidgets('blocked verification can open the gated release case', (
    tester,
  ) async {
    DemoFdrPortalStore.instance.resetDemoData();
    await tester.pumpWidget(const AictePortalApp());
    await tester.enterText(find.byType(TextFormField).first, 'officer-123');
    await tester.enterText(find.byType(TextFormField).last, 'demo-password');
    await tester.ensureVisible(find.text('Sign In to Officer Portal'));
    await tester.tap(find.text('Sign In to Officer Portal'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Review').first);
    await tester.tap(find.widgetWithText(TextButton, 'Review').first);
    await tester.pumpAndSettle();
    expect(find.text('AICTE Officer Portal'), findsOneWidget);
    expect(find.text('Security Deposit Management'), findsOneWidget);
    final headerTop = tester.getTopLeft(find.text('AICTE Officer Portal')).dy;
    await tester.scrollUntilVisible(
      find.text('Run Verification'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    expect(tester.getTopLeft(find.text('AICTE Officer Portal')).dy, headerTop);
    await tester.tap(find.text('Run Verification'));
    await tester.pumpAndSettle();
    expect(find.text('Verification Results'), findsOneWidget);
    expect(find.text('AICTE Officer Portal'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Open Blocked Release Case'),
      450,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('Open Blocked Release Case'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Blocked Release Case'));
    await tester.pumpAndSettle();

    expect(find.text('Release / Refund Case'), findsOneWidget);
    expect(find.text('Case Summary'), findsOneWidget);
    expect(find.text('Blocked — FDR Verification'), findsOneWidget);
    expect(find.text('AICTE Officer Portal'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Required Documents'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Required Documents'), findsWidgets);

    final caseTypeDropdown = find.byType(DropdownButtonFormField<String>);
    await tester.scrollUntilVisible(
      caseTypeDropdown,
      -350,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(caseTypeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Progressive Closure').last);
    await tester.pumpAndSettle();
    expect(find.text('PCL-2026-00008'), findsOneWidget);
    expect(find.text('Partial Release Request'), findsWidgets);

    await tester.scrollUntilVisible(
      caseTypeDropdown,
      -350,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(caseTypeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merger').last);
    await tester.pumpAndSettle();
    expect(DemoFdrPortalStore.instance.selectedCaseType, 'Merger');
    expect(find.text('Merger').first, findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Successor institution'),
      350,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Successor institution'), findsWidgets);

    await tester.scrollUntilVisible(
      caseTypeDropdown,
      -350,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(caseTypeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Normal Release').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Simulate Final NOC'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Simulate Final NOC'),
          )
          .onPressed,
      isNull,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Verification Results'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('View Audit Trail'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('View Audit Trail'));
    await tester.pumpAndSettle();
    expect(find.text('Audit Trail'), findsOneWidget);
    expect(find.text('AICTE Officer Portal'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('eligible Normal Release enables and audits simulated Final NOC', (
    tester,
  ) async {
    final store = DemoFdrPortalStore.instance;
    store.resetDemoData();
    store.setCurrentSubmission(
      store.currentSubmission.copyWith(
        fdrNumber: 'FDR-UNIQUE-WIDGET',
        declaredDepositAmount: 450000,
      ),
    );
    store.createReleaseCase();
    store.updateClearanceStatus('Grievance Redressal Cell', 'Cleared');
    store.updateClearanceStatus('Vigilance Cell', 'Cleared');

    await tester.pumpWidget(const AictePortalApp());
    await tester.enterText(find.byType(TextFormField).first, 'officer-123');
    await tester.enterText(find.byType(TextFormField).last, 'demo-password');
    await tester.ensureVisible(find.text('Sign In to Officer Portal'));
    await tester.tap(find.text('Sign In to Officer Portal'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Review').first);
    await tester.tap(find.widgetWithText(TextButton, 'Review').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Run Verification'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Run Verification'));
    await tester.pumpAndSettle();

    expect(find.text('REL-2026-00017'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Open Release / Refund Case'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Open Release / Refund Case'));
    await tester.pumpAndSettle();

    expect(find.text('Ready for Final NOC'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Simulate Final NOC'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    final nocButton = find.widgetWithText(FilledButton, 'Simulate Final NOC');
    expect(tester.widget<FilledButton>(nocButton).onPressed, isNotNull);

    await tester.ensureVisible(nocButton);
    await tester.pumpAndSettle();
    await tester.tap(nocButton);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This records a local demo outcome only. It is not an official NOC and does not release funds.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirm demo action'));
    await tester.pumpAndSettle();

    expect(find.text('NOC Issued — Demo'), findsWidgets);
    expect(
      store.auditEntries.any(
        (entry) =>
            entry.action == 'Final NOC simulated' &&
            entry.associatedId == 'REL-2026-00017',
      ),
      isTrue,
    );
  });

  testWidgets(
    'correct details save latest values and require explicit verification',
    (tester) async {
      final store = DemoFdrPortalStore.instance;
      store.resetDemoData();
      final receiptAmount = store.currentSubmission.receiptAmount;

      await tester.pumpWidget(const AictePortalApp());
      await tester.enterText(find.byType(TextFormField).first, 'officer-123');
      await tester.enterText(find.byType(TextFormField).last, 'demo-password');
      await tester.ensureVisible(find.text('Sign In to Officer Portal'));
      await tester.tap(find.text('Sign In to Officer Portal'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Review').first,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Review').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Run Verification'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Run Verification'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Correct Details'),
        350,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Correct Details'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(1), '450000');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Corrected Details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Corrected Details'));
      await tester.pumpAndSettle();

      expect(store.currentSubmission.submissionId, 'FDR-2026-00124');
      expect(store.currentSubmission.declaredDepositAmount, 450000);
      expect(store.currentSubmission.receiptAmount, receiptAmount);
      expect(store.verificationCurrent, isFalse);
      expect(store.releaseCase!.status, 'Verification Required');
      expect(
        find.textContaining('Corrected FDR details were saved.'),
        findsOneWidget,
      );
      expect(find.text('NOT RUN — Verify saved FDR details'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(3));

      await tester.drag(find.byType(ListView).last, const Offset(0, -450));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Run Verification'));
      await tester.pumpAndSettle();

      expect(store.verificationCurrent, isTrue);
      expect(store.lastVerification.blocking, 1);
      expect(
        store.lastVerification.issues.map((issue) => issue.ruleId),
        contains('duplicate-fdr'),
      );
      expect(
        store.lastVerification.issues.map((issue) => issue.ruleId),
        isNot(contains('deposit-amount')),
      );
      expect(store.releaseCase!.status, 'Blocked — FDR Verification');
    },
  );

  test('shared audit chain verifies appended demo events', () {
    final store = DemoFdrPortalStore.instance;
    store.resetDemoData();
    store.appendAuditEntry(
      action: 'Required document marked missing',
      associatedId: 'REL-2026-00017',
      actorRole: 'Demo Officer',
      payload: 'request_letter.pdf',
    );

    final result = verifyAuditChain(store.auditEntries);

    expect(result.isValid, isTrue);
    expect(result.invalidEntryId, isNull);
  });

  test(
    'progressive closure validation rejects invalid amounts and prevents negative retained balances',
    () {
      final originalAmount = 500000;
      final availableBalance = 500000;

      expect(
        ReleaseEligibilityService.validateRequestedAmount(
          '150000',
          originalFdrAmount: originalAmount,
          availableBalance: availableBalance,
        ),
        isNull,
      );
      expect(
        ReleaseEligibilityService.validateRequestedAmount(
          '500000',
          originalFdrAmount: originalAmount,
          availableBalance: availableBalance,
        ),
        isNull,
      );
      expect(
        ReleaseEligibilityService.validateRequestedAmount(
          '5000001',
          originalFdrAmount: originalAmount,
          availableBalance: availableBalance,
        ),
        isNotNull,
      );
      expect(
        ReleaseEligibilityService.validateRequestedAmount(
          '600000',
          originalFdrAmount: originalAmount,
          availableBalance: availableBalance,
        ),
        isNotNull,
      );
      expect(
        ReleaseEligibilityService.validateRequestedAmount(
          '0',
          originalFdrAmount: originalAmount,
          availableBalance: availableBalance,
        ),
        isNotNull,
      );
      expect(
        ReleaseEligibilityService.validateRequestedAmount(
          '-100',
          originalFdrAmount: originalAmount,
          availableBalance: availableBalance,
        ),
        isNotNull,
      );
      expect(
        ReleaseEligibilityService.validateRequestedAmount(
          '',
          originalFdrAmount: originalAmount,
          availableBalance: availableBalance,
        ),
        isNotNull,
      );
      expect(
        ReleaseEligibilityService.validateRequestedAmount(
          'abc',
          originalFdrAmount: originalAmount,
          availableBalance: availableBalance,
        ),
        isNotNull,
      );

      final valid = ReleaseEligibilityService.evaluate(
        record: const ReleaseCase(
          caseId: 'PCL-001',
          submissionId: 'SUB-001',
          institution: 'Demo Institution',
          caseType: 'Progressive Closure',
          status: 'Pending Review',
          checklist: [
            DemoChecklistItem(
              name: 'Required document',
              fileName: 'doc.pdf',
              status: 'Present — Demo',
            ),
          ],
          clearances: [
            ClearanceState(
              name: 'Grievance Redressal Cell',
              status: 'Cleared',
              remark: 'Reviewed',
              actionRequired: 'Review grievances.',
            ),
            ClearanceState(
              name: 'Vigilance Cell',
              status: 'Cleared',
              remark: 'Reviewed',
              actionRequired: 'Inspect compliance.',
            ),
          ],
          originalFdrAmount: 500000,
          availableBalance: 500000,
          requestedReleaseAmount: 150000,
          partialReleaseReason: 'Stage release',
          originalFdrReference: 'FDR-PCL-552901',
        ),
        verification: const VerificationSummary(
          totalChecks: 0,
          blocking: 0,
          warnings: 0,
          statusText: 'Demo verification passed',
          issues: [],
        ),
      );
      expect(valid.canAdvance, isTrue);
      expect(valid.blockingReasons, isEmpty);
      expect(150000 + valid.missingDocuments.length, equals(150000));

      final invalid = ReleaseEligibilityService.evaluate(
        record: const ReleaseCase(
          caseId: 'PCL-002',
          submissionId: 'SUB-002',
          institution: 'Demo Institution',
          caseType: 'Progressive Closure',
          status: 'Pending Review',
          checklist: [
            DemoChecklistItem(
              name: 'Required document',
              fileName: 'doc.pdf',
              status: 'Present — Demo',
            ),
          ],
          clearances: [
            ClearanceState(
              name: 'Grievance Redressal Cell',
              status: 'Cleared',
              remark: 'Reviewed',
              actionRequired: 'Review grievances.',
            ),
            ClearanceState(
              name: 'Vigilance Cell',
              status: 'Cleared',
              remark: 'Reviewed',
              actionRequired: 'Inspect compliance.',
            ),
          ],
          originalFdrAmount: 500000,
          availableBalance: 500000,
          requestedReleaseAmount: 600000,
          partialReleaseReason: 'Stage release',
          originalFdrReference: 'FDR-PCL-552901',
        ),
        verification: const VerificationSummary(
          totalChecks: 0,
          blocking: 0,
          warnings: 0,
          statusText: 'Demo verification passed',
          issues: [],
        ),
      );
      expect(invalid.canAdvance, isFalse);
      expect(
        invalid.blockingReasons.join(' '),
        contains('original FDR amount'),
      );
      expect(invalid.blockingReasons.join(' '), contains('negative'));
    },
  );

  test(
    'missing documents and workflow progression are derived from actual checklist states',
    () {
      final store = DemoFdrPortalStore.instance;
      store.resetDemoData();
      store.createReleaseCase();
      store.updateReleaseCaseType('Progressive Closure');

      final partial = store.releaseCase!.copyWith(
        checklist: const [
          DemoChecklistItem(
            name: 'Institution partial release request',
            fileName: 'pcl_request_letter.pdf',
            type: 'Signed request letter',
            isRequired: true,
            isPresent: false,
            status: 'Missing — Demo',
          ),
          DemoChecklistItem(
            name: 'Updated FDR evidence',
            fileName: 'pcl_fdr_copy.pdf',
            type: 'FDR copy',
            isRequired: true,
            isPresent: true,
            status: 'Present — Demo',
          ),
          DemoChecklistItem(
            name: 'Partial release justification',
            fileName: 'pcl_justification.pdf',
            type: 'Supporting justification',
            isRequired: true,
            isPresent: true,
            status: 'Present — Demo',
          ),
        ],
        clearances: const [
          ClearanceState(
            name: 'Grievance Redressal Cell',
            status: 'Cleared',
            remark: 'Reviewed',
            actionRequired: 'Review grievances.',
          ),
          ClearanceState(
            name: 'Vigilance Cell',
            status: 'Cleared',
            remark: 'Reviewed',
            actionRequired: 'Inspect compliance.',
          ),
        ],
      );

      final missing = ReleaseEligibilityService.evaluate(
        record: partial,
        verification: const VerificationSummary(
          totalChecks: 0,
          blocking: 0,
          warnings: 0,
          statusText: 'Demo verification passed',
          issues: [],
        ),
      );
      expect(missing.canAdvance, isFalse);
      expect(
        missing.missingDocuments,
        contains('Institution partial release request'),
      );
      expect(missing.nextEligibleStage, 'Required Documents');

      final restored = ReleaseEligibilityService.evaluate(
        record: partial.copyWith(
          checklist: const [
            DemoChecklistItem(
              name: 'Institution partial release request',
              fileName: 'pcl_request_letter.pdf',
              type: 'Signed request letter',
              isRequired: true,
              isPresent: true,
              status: 'Present — Demo',
            ),
            DemoChecklistItem(
              name: 'Updated FDR evidence',
              fileName: 'pcl_fdr_copy.pdf',
              type: 'FDR copy',
              isRequired: true,
              isPresent: true,
              status: 'Present — Demo',
            ),
            DemoChecklistItem(
              name: 'Partial release justification',
              fileName: 'pcl_justification.pdf',
              type: 'Supporting justification',
              isRequired: true,
              isPresent: true,
              status: 'Present — Demo',
            ),
          ],
        ),
        verification: const VerificationSummary(
          totalChecks: 0,
          blocking: 0,
          warnings: 0,
          statusText: 'Demo verification passed',
          issues: [],
        ),
      );
      expect(restored.canAdvance, isTrue);
      expect(restored.missingDocuments, isEmpty);
    },
  );

  test(
    'clearance decisions remain independent for each case and block approval until all cells are cleared',
    () {
      final store = DemoFdrPortalStore.instance;
      store.resetDemoData();
      store.createReleaseCase();
      store.updateReleaseCaseType('Progressive Closure');

      final pending = store.releaseCase!.copyWith(
        clearances: const [
          ClearanceState(
            name: 'Grievance Redressal Cell',
            status: 'Cleared',
            remark: 'Reviewed',
            actionRequired: 'Review grievances.',
          ),
          ClearanceState(
            name: 'Vigilance Cell',
            status: 'Pending',
            remark: 'Not reviewed',
            actionRequired: 'Inspect compliance.',
          ),
        ],
        checklist: const [
          DemoChecklistItem(
            name: 'Institution partial release request',
            fileName: 'pcl_request_letter.pdf',
            type: 'Signed request letter',
            isRequired: true,
            isPresent: true,
            status: 'Present — Demo',
          ),
          DemoChecklistItem(
            name: 'Updated FDR evidence',
            fileName: 'pcl_fdr_copy.pdf',
            type: 'FDR copy',
            isRequired: true,
            isPresent: true,
            status: 'Present — Demo',
          ),
          DemoChecklistItem(
            name: 'Partial release justification',
            fileName: 'pcl_justification.pdf',
            type: 'Supporting justification',
            isRequired: true,
            isPresent: true,
            status: 'Present — Demo',
          ),
        ],
        requestedReleaseAmount: 150000,
        partialReleaseReason: 'Stage release',
      );

      final blocked = ReleaseEligibilityService.evaluate(
        record: pending,
        verification: const VerificationSummary(
          totalChecks: 0,
          blocking: 0,
          warnings: 0,
          statusText: 'Demo verification passed',
          issues: [],
        ),
      );
      expect(blocked.canAdvance, isFalse);
      expect(blocked.pendingClearances, contains('Vigilance Cell'));

      final cleared = pending.copyWith(
        clearances: const [
          ClearanceState(
            name: 'Grievance Redressal Cell',
            status: 'Cleared',
            remark: 'Reviewed',
            actionRequired: 'Review grievances.',
          ),
          ClearanceState(
            name: 'Vigilance Cell',
            status: 'Cleared',
            remark: 'Reviewed',
            actionRequired: 'Inspect compliance.',
          ),
        ],
      );
      final eligible = ReleaseEligibilityService.evaluate(
        record: cleared,
        verification: const VerificationSummary(
          totalChecks: 0,
          blocking: 0,
          warnings: 0,
          statusText: 'Demo verification passed',
          issues: [],
        ),
      );
      expect(eligible.canAdvance, isTrue);
    },
  );

  test(
    'merger approval requires all configured requirements and preserves the original FDR record',
    () {
      final store = DemoFdrPortalStore.instance;
      store.resetDemoData();
      store.createReleaseCase();
      store.updateReleaseCaseType('Merger');

      final underReview = store.releaseCase!.copyWith(
        successorInstitution: 'Demo University',
        mergerReference: 'MERGER-001',
        effectiveDate: '01 November 2026',
        checklist: const [
          DemoChecklistItem(
            name: 'Merger or amalgamation approval document',
            fileName: 'merger_approval.pdf',
            type: 'Merger approval',
            isRequired: true,
            isPresent: true,
            status: 'Present — Demo',
          ),
          DemoChecklistItem(
            name: 'Institution request letter',
            fileName: 'merger_request_letter.pdf',
            type: 'Institution request',
            isRequired: true,
            isPresent: true,
            status: 'Present — Demo',
          ),
          DemoChecklistItem(
            name: 'Original FDR copy',
            fileName: 'merger_original_fdr.pdf',
            type: 'Original FDR copy',
            isRequired: true,
            isPresent: false,
            status: 'Missing — Demo',
          ),
          DemoChecklistItem(
            name: 'Supporting institution records',
            fileName: 'merger_institution_records.pdf',
            type: 'Institution records',
            isRequired: true,
            isPresent: true,
            status: 'Present — Demo',
          ),
        ],
        clearances: const [
          ClearanceState(
            name: 'Grievance Redressal Cell',
            status: 'Cleared',
            remark: 'Reviewed',
            actionRequired: 'Review grievances.',
          ),
          ClearanceState(
            name: 'Vigilance Cell',
            status: 'Pending',
            remark: 'Not reviewed',
            actionRequired: 'Inspect compliance.',
          ),
        ],
      );

      final blocked = ReleaseEligibilityService.evaluate(
        record: underReview,
        verification: const VerificationSummary(
          totalChecks: 0,
          blocking: 0,
          warnings: 0,
          statusText: 'Demo verification passed',
          issues: [],
        ),
        originalFdrExists: true,
      );
      expect(blocked.canAdvance, isFalse);
      expect(blocked.missingDocuments, contains('Original FDR copy'));
      expect(blocked.pendingClearances, contains('Vigilance Cell'));

      store.updateClearanceStatus('Grievance Redressal Cell', 'Cleared');
      store.updateClearanceStatus('Vigilance Cell', 'Cleared');
      store.updateDocumentPresence('merger_original_fdr.pdf', true);
      store.setLastVerification(_passedVerification);
      store.approveMergerInDemoMode();

      expect(store.releaseCase!.status, 'Merger Approved — Demo');
      expect(
        store.mergerRelationships['FDR-MRG-330812'],
        'Example Technical University',
      );
      expect(store.demoFdrRecords['FDR-MRG-330812']!.amount, 500000);
      expect(
        store.demoFdrRecords['FDR-MRG-330812']!.institution,
        'Example Institute of Technology',
      );
    },
  );

  test('audit chain catches tampered event content and broken linkage', () {
    final store = DemoFdrPortalStore.instance;
    store.resetDemoData();
    store.appendAuditEntry(
      action: 'Case type selected',
      associatedId: 'PCL-2026-00008',
      actorRole: 'Demo Officer',
      payload: 'Progressive Closure',
    );

    final valid = verifyAuditChain(store.auditEntries);
    expect(valid.isValid, isTrue);

    final tamperedAction = store.auditEntries.last.copyWith(
      action: 'Approval forged',
    );
    final tamperedEntry = tamperedAction.copyWith(
      entryHash: 'TAMPERED-${tamperedAction.eventId}',
    );
    final alteredEntries = [
      ...store.auditEntries.sublist(0, store.auditEntries.length - 1),
      tamperedEntry,
    ];
    final tamperedResult = verifyAuditChain(alteredEntries);
    expect(tamperedResult.isValid, isFalse);
    expect(tamperedResult.invalidEntryId, isNotNull);

    final brokenLinkEntries = List<AuditEntry>.from(store.auditEntries);
    brokenLinkEntries[1] = brokenLinkEntries[1].copyWith(
      previousHash: 'BROKEN-LINK',
    );
    final brokenLinkResult = verifyAuditChain(brokenLinkEntries);
    expect(brokenLinkResult.isValid, isFalse);
  });
}
