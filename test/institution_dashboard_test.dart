import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fds_aicte/institution_dashboard.dart';
import 'package:fds_aicte/main.dart';
import 'package:fds_aicte/notification_center.dart';
import 'package:fds_aicte/officer_dashboard.dart';
import 'package:fds_aicte/portal_foundations.dart';

void main() {
  setUp(() => InstitutionDemoStore.instance.resetDemoData());

  testWidgets(
    'institution can review counts, submit an FDR, and open details',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const AictePortalApp());
      await tester.tap(find.text('Institution'));
      await tester.enterText(
        find.byType(TextFormField).first,
        'institution-demo',
      );
      await tester.enterText(find.byType(TextFormField).last, 'demo-password');
      await tester.ensureVisible(find.text('Sign In to Institution Portal'));
      await tester.tap(find.text('Sign In to Institution Portal'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back, Administrator'), findsOneWidget);
      expect(find.text('Example Institute of Technology'), findsWidgets);
      expect(find.text('INST-0042'), findsOneWidget);

      final totalCard = find.byKey(
        const ValueKey('institution-metric:Total FDRs'),
      );
      final pendingCard = find.byKey(
        const ValueKey('institution-metric:Pending Verification'),
      );
      final verifiedCard = find.byKey(
        const ValueKey('institution-metric:Verified FDRs'),
      );
      final actionCard = find.byKey(
        const ValueKey('institution-metric:Rejected / Action Required'),
      );
      expect(
        find.descendant(of: totalCard, matching: find.text('4')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pendingCard, matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: verifiedCard, matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: actionCard, matching: find.text('2')),
        findsOneWidget,
      );

      await tester.tap(verifiedCard);
      await tester.pumpAndSettle();
      expect(find.text('FDR-EIT-771530'), findsOneWidget);
      expect(find.text('FDR-EIT-884201'), findsNothing);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit New FDR'));
      await tester.tap(find.text('Submit New FDR'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Demo Trust Bank',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'FDR-EIT-NEW-9001',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '275000');
      await tester.tap(find.text('Save Submission'));
      await tester.pumpAndSettle();

      expect(find.text('My Submissions'), findsWidgets);
      expect(find.text('FDR-EIT-NEW-9001'), findsOneWidget);
      expect(find.text('Pending Review'), findsWidgets);
      await tester.tap(find.text('FDR-EIT-NEW-9001').first);
      await tester.pumpAndSettle();
      expect(find.text('Submission Details'), findsOneWidget);
      expect(find.text('Demo Trust Bank'), findsWidgets);
      expect(find.text('₹2,75,000'), findsWidgets);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: totalCard, matching: find.text('5')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pendingCard, matching: find.text('2')),
        findsOneWidget,
      );

      await tester.tap(find.text('Release / Refund'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New release or refund request'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('FDR-EIT-NEW-9001').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '100000');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Demo closure request',
      );
      await tester.tap(find.text('Save Request'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Normal Release request · REL-'),
        findsOneWidget,
      );
      expect(find.text('Demo closure request'), findsOneWidget);
    },
  );

  test('institution demo counts are derived from the record list', () {
    final records = InstitutionDemoStore.instance.submissions;
    expect(records.length, 4);
    expect(
      records
          .where(
            (record) => record.status == InstitutionSubmissionStatus.pending,
          )
          .length,
      1,
    );
    expect(
      records
          .where(
            (record) => record.status == InstitutionSubmissionStatus.verified,
          )
          .length,
      1,
    );
    expect(
      records
          .where(
            (record) =>
                record.status == InstitutionSubmissionStatus.rejected ||
                record.status == InstitutionSubmissionStatus.actionRequired,
          )
          .length,
      2,
    );
  });

  test(
    'institution FDR submission is immediately visible to every officer',
    () {
      final institutionStore = InstitutionDemoStore.instance;
      final officerStore = DemoFdrPortalStore.instance;
      final beforeCount =
          const MockOfficerDashboardRepository().summary['Pending Review'];
      final created = institutionStore.addSubmission(
        fdrNumber: 'FDR-EIT-SHARED-9002',
        bankName: 'Shared Demo Bank',
        amount: 625000,
      );

      expect(
        officerStore.submissionById(created.id)?.reference,
        'FDR-EIT-SHARED-9002',
      );
      expect(
        const MockOfficerDashboardRepository().pendingSubmissions.map(
          (record) => record.submissionId,
        ),
        contains(created.id),
      );
      expect(
        const MockOfficerDashboardRepository().summary['Pending Review'],
        beforeCount! + 1,
      );
      expect(
        institutionStore.submissions.where((record) => record.id == created.id),
        hasLength(1),
      );
      expect(institutionStore.submissionById('FDR-2026-00125'), isNull);
      expect(
        const MockOfficerDashboardRepository().summary['Total Institutions'],
        3,
      );
    },
  );

  testWidgets('officer Review opens the institution FDR and release case', (
    tester,
  ) async {
    final institutionStore = InstitutionDemoStore.instance;
    institutionStore.addSubmission(
      fdrNumber: 'FDR-EIT-OFFICER-9005',
      bankName: 'Officer Review Demo Bank',
      amount: 410000,
    );
    expect(
      const MockOfficerDashboardRepository().submissions.map(
        (record) => record.reference,
      ),
      contains('FDR-EIT-OFFICER-9005'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OfficerDashboardScreen(userId: 'officer-demo', onSignOut: () {}),
      ),
    );

    await tester.ensureVisible(
      find.text('FDR reference  FDR-EIT-OFFICER-9005', findRichText: true),
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Review').first,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Review').first);
    await tester.pumpAndSettle();
    expect(find.text('FDR Verification'), findsOneWidget);
    expect(
      find.textContaining('FDR-EIT-OFFICER-9005', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Officer Review Bank', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('INST-0042', findRichText: true), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    institutionStore.addReleaseRequest(
      fdrNumber: 'FDR-EIT-771530',
      requestType: 'Progressive Closure',
      amount: 125000,
      reason: 'Officer case detail check',
      caseType: 'Progressive Closure',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text('FDR reference  FDR-EIT-771530', findRichText: true).first,
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Review').first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Review').first);
    await tester.pumpAndSettle();
    final reviewedCase = DemoFdrPortalStore.instance.releaseCase!;
    expect(reviewedCase.caseType, 'Progressive Closure');
    expect(find.text('Release / Refund Case'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Case Type'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('case-type-Progressive Closure')),
      findsOneWidget,
    );
    expect(
      find.textContaining(reviewedCase.caseId, findRichText: true),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Case Summary'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('₹125,000'), findsOneWidget);
    expect(find.text('₹225,000'), findsOneWidget);
    expect(find.text('Officer case detail check'), findsOneWidget);
  });

  test(
    'release case types are shared with full case details and unique IDs',
    () {
      final institutionStore = InstitutionDemoStore.instance;
      final officerStore = DemoFdrPortalStore.instance;
      final institutionCount =
          const MockOfficerDashboardRepository().summary['Total Institutions'];
      final requests = [
        ('Normal Release', 100000),
        ('Progressive Closure', 150000),
        ('Merger', 0),
      ];
      final created = <InstitutionSubmission>[];
      for (final (caseType, amount) in requests) {
        institutionStore.addReleaseRequest(
          fdrNumber: 'FDR-EIT-771530',
          requestType: caseType,
          amount: amount,
          reason: 'Shared $caseType demo request',
          caseType: caseType,
          successorInstitution: caseType == 'Merger'
              ? 'Example Successor University'
              : '',
          mergerReference: caseType == 'Merger' ? 'MERGER-EIT-42' : '',
          effectiveDate: caseType == 'Merger' ? '01 Nov 2026' : '',
        );

        created.add(institutionStore.submissions.first);
      }

      final releaseRows = officerStore.dashboardSubmissions
          .where((record) => record.caseId != null)
          .take(3)
          .toList();
      expect(
        releaseRows.map((record) => record.caseType),
        containsAll(['Normal Release', 'Progressive Closure', 'Merger']),
      );
      expect(releaseRows.map((record) => record.caseId).toSet(), hasLength(3));
      final progressive = releaseRows.singleWhere(
        (record) => record.caseType == 'Progressive Closure',
      );
      expect(progressive.requestedAmount, 150000);
      expect(progressive.retainedBalance, 200000);
      final mergerCase = officerStore.releaseCases.singleWhere(
        (record) =>
            record.caseId ==
            releaseRows.singleWhere((row) => row.caseType == 'Merger').caseId,
      );
      expect(mergerCase.institution, 'Example Institute of Technology');
      expect(mergerCase.successorInstitution, 'Example Successor University');
      expect(mergerCase.mergerReference, 'MERGER-EIT-42');
      expect(created, hasLength(3));
      expect(
        const MockOfficerDashboardRepository().summary['Total Institutions'],
        institutionCount,
      );
    },
  );

  test(
    'clarification ownership, exact remark, response, and notifications stay synchronized',
    () async {
      final store = DemoFdrPortalStore.instance;
      final institutionStore = InstitutionDemoStore.instance;
      final first = store.submitInstitutionFdr(
        institution: 'Example Institute of Technology',
        institutionId: 'INST-DEMO-0042',
        bank: 'Clarification Bank',
        fdrNumber: 'FDR-CLARIFICATION-9001',
        amount: 300000,
      );
      final second = store.submitInstitutionFdr(
        institution: 'Other Institute',
        institutionId: 'INST-OTHER-9002',
        bank: 'Other Bank',
        fdrNumber: 'FDR-CLARIFICATION-9002',
        amount: 400000,
      );

      store.requestClarification(
        submissionId: first.submissionId,
        reviewSection: 'FDR verification',
        remark: 'Upload the signed bank confirmation letter.',
        requiredDocument: 'bank_confirmation.pdf',
      );
      store.requestClarification(
        submissionId: first.submissionId,
        reviewSection: 'FDR verification',
        remark: 'Upload the signed bank confirmation letter.',
        requiredDocument: 'bank_confirmation.pdf',
      );

      final clarification = store.clarificationForSubmission(
        first.submissionId,
      );
      expect(
        clarification?.remark,
        'Upload the signed bank confirmation letter.',
      );
      expect(clarification?.reviewSection, 'FDR verification');
      expect(clarification?.requiredDocument, 'bank_confirmation.pdf');
      expect(clarification?.status, 'Clarification Requested');
      expect(
        store.submissionById(first.submissionId)?.status,
        SubmissionStatus.correctionRequested,
      );
      expect(
        store.clarificationsForInstitution('INST-DEMO-0042'),
        hasLength(1),
      );
      expect(store.clarificationsForInstitution('INST-OTHER-9002'), isEmpty);
      expect(
        NotificationCenter.instance
            .forRecipient(
              NotificationRecipientRole.institution,
              recipientId: 'INST-DEMO-0042',
              category: NotificationCategory.clarification,
            )
            .where((item) => item.relatedId == first.submissionId)
            .length,
        1,
      );

      await portalAuthService.authenticate('institution-demo', 'demo-password');
      store.respondToFdrClarification(
        submissionId: first.submissionId,
        response: 'The signed bank confirmation letter is attached.',
        documentStatus: 'bank_confirmation.pdf replaced',
      );
      final response = store.clarificationForSubmission(first.submissionId);
      expect(response?.status, 'Response Submitted');
      expect(
        response?.response,
        'The signed bank confirmation letter is attached.',
      );
      expect(response?.documentStatus, 'bank_confirmation.pdf replaced');
      expect(
        institutionStore.submissionById(second.submissionId)?.institutionId,
        isNull,
      );
      expect(institutionStore.submissionById(first.submissionId), isNotNull);
    },
  );

  test(
    'pending decreases and approved increases only after final case approval',
    () {
      final institutionStore = InstitutionDemoStore.instance;
      final officerStore = DemoFdrPortalStore.instance;
      institutionStore.addReleaseRequest(
        fdrNumber: 'FDR-EIT-771530',
        requestType: 'Progressive Closure',
        amount: 100000,
        reason: 'Final approval test',
        caseType: 'Progressive Closure',
      );
      final created = institutionStore.submissions.first;
      final beforePending =
          const MockOfficerDashboardRepository().summary['Pending Review']!;

      expect(const MockOfficerDashboardRepository().summary['Approved'], 0);
      officerStore.selectReleaseCase(created.caseId!);
      officerStore.runCurrentVerification();
      officerStore.updateClearanceStatus('Grievance Redressal Cell', 'Cleared');
      officerStore.updateClearanceStatus('Vigilance Cell', 'Cleared');
      final eligibility = ReleaseEligibilityService.evaluate(
        record: officerStore.releaseCase!,
        verification: officerStore.verificationForEligibility,
      );
      expect(
        eligibility.canAdvance,
        isTrue,
        reason: eligibility.blockingReasons.join(' '),
      );
      expect(const MockOfficerDashboardRepository().summary['Approved'], 0);

      officerStore.approveProgressiveClosureInDemoMode();

      expect(
        const MockOfficerDashboardRepository().summary['Pending Review'],
        beforePending - 1,
      );
      expect(const MockOfficerDashboardRepository().summary['Approved'], 1);
      expect(
        officerStore.submissionById(created.id)?.status,
        VerificationStatus.approved,
      );
    },
  );

  test('blocking verification or missing documents prevent final approval', () {
    final institutionStore = InstitutionDemoStore.instance;
    final officerStore = DemoFdrPortalStore.instance;
    institutionStore.addReleaseRequest(
      fdrNumber: 'FDR-EX-884201',
      requestType: 'Progressive Closure',
      amount: 100000,
      reason: 'Blocking verification test',
      caseType: 'Progressive Closure',
    );
    final created = institutionStore.submissions.first;
    officerStore.selectReleaseCase(created.caseId!);
    final result = officerStore.runCurrentVerification();
    expect(result.blocking, greaterThan(0));
    officerStore.updateClearanceStatus('Grievance Redressal Cell', 'Cleared');
    officerStore.updateClearanceStatus('Vigilance Cell', 'Cleared');
    officerStore.approveProgressiveClosureInDemoMode();
    expect(const MockOfficerDashboardRepository().summary['Approved'], 0);

    officerStore.setCurrentSubmission(
      officerStore.currentSubmission.copyWith(
        fdrNumber: 'FDR-EIT-771530',
        declaredDepositAmount: 350000,
        receiptAmount: 350000,
        lienInformation: 'No lien',
      ),
    );
    officerStore.setLastVerification(
      const VerificationSummary(
        totalChecks: 1,
        blocking: 0,
        warnings: 0,
        statusText: 'Passed',
        issues: [],
      ),
    );
    officerStore.updateDocumentPresence('fdr_receipt.pdf', false);
    officerStore.approveProgressiveClosureInDemoMode();
    expect(const MockOfficerDashboardRepository().summary['Approved'], 0);
  });

  test(
    'rejected only counts final rejection and institution IDs remain unique',
    () {
      final store = DemoFdrPortalStore.instance;
      final rejectedBefore =
          const MockOfficerDashboardRepository().summary['Needs Correction']!;
      final submitted = InstitutionDemoStore.instance.addSubmission(
        fdrNumber: 'FDR-EIT-REJECT-9003',
        bankName: 'Demo Bank',
        amount: 150000,
      );
      expect(
        const MockOfficerDashboardRepository().summary['Needs Correction'],
        rejectedBefore,
      );
      store.rejectSubmission(submitted.id);
      expect(
        const MockOfficerDashboardRepository().summary['Needs Correction'],
        rejectedBefore + 1,
      );
      expect(
        const MockOfficerDashboardRepository().summary['Total Institutions'],
        3,
      );
    },
  );

  test(
    'officer verification cannot clear a rejected status before resubmission',
    () {
      final store = DemoFdrPortalStore.instance;
      final repository = const MockOfficerDashboardRepository();
      store.selectSubmission('FDR-2026-00128');
      store.runCurrentVerification();

      expect(
        store.submissionById('FDR-2026-00128')?.status,
        VerificationStatus.rejected,
      );
      expect(repository.summary['Needs Correction'], 1);
      expect(repository.summary['Pending Review'], 4);
    },
  );

  test('correction cannot overwrite another institution FDR reference', () {
    final store = DemoFdrPortalStore.instance;
    final repository = const MockOfficerDashboardRepository();
    store.submitInstitutionFdr(
      institution: 'Other Registered Institution',
      institutionId: 'INST-OTHER-9001',
      bank: 'Other Demo Bank',
      fdrNumber: 'FDR-OWNED-OTHER-9001',
      amount: 300000,
    );
    final ownSubmission = InstitutionDemoStore.instance.addSubmission(
      fdrNumber: 'FDR-EIT-CORRECTION-9002',
      bankName: 'Example Bank',
      amount: 180000,
    );
    store.rejectSubmission(ownSubmission.id, reason: 'Incorrect FDR reference');
    final institutionCountAfterRegistration =
        repository.summary['Total Institutions'];

    final verification = store.saveInstitutionCorrection(
      submissionId: ownSubmission.id,
      institutionId: 'INST-DEMO-0042',
      bank: 'Example Bank',
      fdrNumber: 'FDR-OWNED-OTHER-9001',
      declaredAmount: 300000,
      receiptAmount: 300000,
    );

    expect(verification.blocking, greaterThan(0));
    expect(
      store.demoFdrRecords['FDR-OWNED-OTHER-9001']?.institutionId,
      'INST-OTHER-9001',
    );
    expect(
      repository.summary['Total Institutions'],
      institutionCountAfterRegistration,
    );
    expect(
      store.submissionById(ownSubmission.id)?.status,
      VerificationStatus.rejected,
    );
  });

  test(
    'correction stays rejected until resubmitted and explicitly approved',
    () {
      final store = DemoFdrPortalStore.instance;
      final institutionStore = InstitutionDemoStore.instance;
      final repository = const MockOfficerDashboardRepository();
      final submitted = institutionStore.addSubmission(
        fdrNumber: 'FDR-EIT-LIFECYCLE-9004',
        bankName: 'Lifecycle Demo Bank',
        amount: 200000,
      );
      store.rejectSubmission(submitted.id, reason: 'Receipt amount mismatch');

      final pendingBefore = repository.summary['Pending Review']!;
      final rejectedBefore = repository.summary['Needs Correction']!;
      final institutionCount = repository.summary['Total Institutions'];
      var verification = store.saveInstitutionCorrection(
        submissionId: submitted.id,
        institutionId: 'INST-DEMO-0042',
        bank: 'Lifecycle Demo Bank',
        fdrNumber: 'FDR-EIT-LIFECYCLE-9004',
        declaredAmount: 200000,
        receiptAmount: 150000,
      );

      expect(verification.blocking, 1);
      expect(
        store.submissionById(submitted.id)?.status,
        VerificationStatus.rejected,
      );
      expect(repository.summary['Approved'], 0);
      expect(
        store.resubmitCorrectedSubmission(submitted.id, 'INST-DEMO-0042'),
        isFalse,
      );
      expect(repository.summary['Needs Correction'], rejectedBefore);

      verification = store.saveInstitutionCorrection(
        submissionId: submitted.id,
        institutionId: 'INST-DEMO-0042',
        bank: 'Lifecycle Demo Bank',
        fdrNumber: 'FDR-EIT-LIFECYCLE-9004-CORRECTED',
        declaredAmount: 150000,
        receiptAmount: 150000,
      );
      expect(verification.blocking, 0);
      expect(
        store.submissionById(submitted.id)?.status,
        VerificationStatus.rejected,
      );
      expect(
        store.submissionById(submitted.id)?.rejectionReason,
        'Receipt amount mismatch',
      );
      expect(
        store.resubmitCorrectedSubmission(submitted.id, 'INST-DEMO-0042'),
        isTrue,
      );

      expect(repository.summary['Pending Review'], pendingBefore + 1);
      expect(repository.summary['Needs Correction'], rejectedBefore - 1);
      expect(
        store.submissionById(submitted.id)?.status,
        VerificationStatus.pending,
      );
      expect(
        store.dashboardSubmissions.where(
          (record) => record.submissionId == submitted.id,
        ),
        hasLength(1),
      );
      expect(repository.summary['Total Institutions'], institutionCount);

      store.selectSubmission(submitted.id);
      store.createReleaseCase();
      store.runCurrentVerification();
      expect(
        store.submissionById(submitted.id)?.status,
        VerificationStatus.pending,
      );
      expect(store.canApproveFdrSubmissionInDemoMode(), isFalse);
      store.updateClearanceStatus('Grievance Redressal Cell', 'Cleared');
      store.updateClearanceStatus('Vigilance Cell', 'Cleared');
      expect(store.canApproveFdrSubmissionInDemoMode(), isTrue);
      expect(store.approveFdrSubmissionInDemoMode(), isTrue);

      expect(
        store.submissionById(submitted.id)?.status,
        VerificationStatus.approved,
      );
      expect(
        repository.pendingSubmissions.map((record) => record.submissionId),
        isNot(contains(submitted.id)),
      );
      expect(
        repository.submissions
            .where((record) => record.status == VerificationStatus.rejected)
            .map((record) => record.submissionId),
        isNot(contains(submitted.id)),
      );
      expect(repository.summary['Pending Review'], pendingBefore);
      expect(repository.summary['Approved'], 1);
      expect(repository.summary['Needs Correction'], rejectedBefore - 1);
      expect(repository.summary['Total Institutions'], institutionCount);
      expect(store.submissionById(submitted.id)?.correctionHistory, isNotEmpty);
    },
  );

  testWidgets(
    'institution correction page requires a clean verification to resubmit',
    (tester) async {
      final store = DemoFdrPortalStore.instance;
      const submissionId = 'FDR-2026-00128';
      store.rejectSubmission(
        submissionId,
        reason: 'Previous officer rejection reason',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: InstitutionCorrectionPage(submissionId: submissionId),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(1),
        'FDR-EIT-440098-CORRECTED',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '750000');
      await tester.enterText(find.byType(TextFormField).at(3), '700000');
      await tester.ensureVisible(find.text('Save Corrected Details'));
      await tester.tap(find.text('Save Corrected Details'));
      await tester.pumpAndSettle();

      expect(find.text('Blocking issues remain'), findsOneWidget);
      expect(find.textContaining('does not match'), findsOneWidget);
      expect(find.text('Resubmit for Officer Review'), findsNothing);
      expect(
        store.submissionById(submissionId)?.status,
        VerificationStatus.rejected,
      );
      expect(const MockOfficerDashboardRepository().summary['Approved'], 0);

      await tester.enterText(find.byType(TextFormField).at(2), '700000');
      await tester.ensureVisible(find.text('Save Corrected Details'));
      await tester.tap(find.text('Save Corrected Details'));
      await tester.pumpAndSettle();
      expect(find.text('Verification passed'), findsOneWidget);
      expect(
        store.submissionById(submissionId)?.status,
        VerificationStatus.rejected,
      );
      expect(
        store.submissionById(submissionId)?.rejectionReason,
        'Previous officer rejection reason',
      );

      await tester.ensureVisible(find.text('Resubmit for Officer Review'));
      await tester.tap(find.text('Resubmit for Officer Review'));
      await tester.pumpAndSettle();
      expect(
        store.submissionById(submissionId)?.status,
        VerificationStatus.pending,
      );
      expect(const MockOfficerDashboardRepository().summary['Approved'], 0);
      expect(
        store.dashboardSubmissions.where(
          (record) => record.submissionId == submissionId,
        ),
        hasLength(1),
      );
    },
  );
}
