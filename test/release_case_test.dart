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
  DemoChecklistItem(name: 'Request Letter', fileName: 'request_letter.pdf', status: 'Present — Demo'),
];

const _clearedCells = [
  ClearanceState(name: 'Grievance Redressal Cell', status: 'Cleared', remark: 'Reviewed', actionRequired: 'Review grievances.'),
  ClearanceState(name: 'Vigilance Cell', status: 'Cleared', remark: 'Reviewed', actionRequired: 'Review compliance.'),
];

void main() {
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
        ClearanceState(name: 'Grievance Redressal Cell', status: 'Cleared', remark: 'Reviewed', actionRequired: 'Review grievances.'),
        ClearanceState(name: 'Vigilance Cell', status: 'Clarification Requested', remark: 'Need details', actionRequired: 'Review compliance.'),
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

  testWidgets('blocked verification can open the gated release case', (tester) async {
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
    await tester.scrollUntilVisible(
      find.text('Run Verification'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Run Verification'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Open Blocked Release Case'),
      450,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Open Blocked Release Case'));
    await tester.pumpAndSettle();

    expect(find.text('Release / Refund Case'), findsOneWidget);
    expect(find.text('Case Summary'), findsOneWidget);
    expect(find.text('Required Documents'), findsWidgets);
  });

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
}