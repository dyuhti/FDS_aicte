import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fds_aicte/institution_dashboard.dart';
import 'package:fds_aicte/main.dart';
import 'package:fds_aicte/officer_dashboard.dart';
import 'package:fds_aicte/portal_foundations.dart';

void main() {
  final store = DemoFdrPortalStore.instance;

  setUp(() {
    store.resetDemoData();
  });

  group('F1 discrepancy and comparison coverage', () {
    test('comparison exposes every source for every verification field', () {
      final values = <DocumentSource, Map<String, String?>>{
        for (final source in DocumentSource.values)
          source: {
            'institutionName': source == DocumentSource.affidavit ? 'Different Institute' : 'Example Institute',
            'trustName': source == DocumentSource.receipt ? 'Different Trust' : 'Example Trust',
            'fdrNumber': 'FDR-X',
            'bank': 'Bank X',
            'depositAmount': '500000',
            'issueDate': '01 January 2025',
            'maturityDate': '01 January 2028',
            'tenureMonths': '36',
            'lienInfo': 'No lien',
          },
      };
      final summary = FdrVerificationService.runVerification(
        FdrRecord(
          institution: 'Example Institute', institutionId: 'I-1',
          submissionId: 'S-1', bank: 'Bank X', fdrNumber: 'FDR-X',
          declaredDepositAmount: 500000, receiptAmount: 500000,
          issueDate: '01 January 2025', maturityDate: '01 January 2028',
          declaredTenureMonths: 36, enteredTenureMonths: 36,
          lienInformation: 'No lien', submissionStatus: 'Pending Review',
          documents: const [], sourceValues: values,
        ),
      );
      expect(summary.comparisonMatrix, hasLength(9));
      for (final row in summary.comparisonMatrix) {
        expect(row.values.keys, containsAll(DocumentSource.values));
      }
      expect(
        summary.comparisonMatrix.firstWhere((row) => row.field == 'institutionName').status,
        ComparisonStatus.partialMismatch,
      );
      expect(
        summary.issues.map((issue) => issue.ruleId),
        containsAll(['institution-name-mismatch', 'trust-name-mismatch']),
      );
      expect(
        summary.issues.firstWhere((issue) => issue.ruleId == 'trust-name-mismatch').severity,
        VerificationIssueSeverity.warning,
      );
    });

    test('changing rule config changes verification output', () {
      final record = FdrRecord(
        institution: 'Example Institute', institutionId: 'I-1',
        submissionId: 'S-1', bank: 'Bank', fdrNumber: 'FDR-X',
        declaredDepositAmount: 500000, receiptAmount: 450000,
        issueDate: '01 January 2025', maturityDate: '01 January 2028',
        declaredTenureMonths: 36, enteredTenureMonths: 36,
        lienInformation: 'No lien', submissionStatus: 'Pending Review',
        documents: const [],
      );
      final defaultResult = FdrVerificationService.runVerification(record);
      final customRules = defaultRuleConfigs().map((rule) =>
          rule.id == 'deposit-amount'
              ? rule.copyWith(params: {'tolerance': 60000})
              : rule).toList();
      final changed = FdrVerificationService.runVerification(record, rules: customRules);
      expect(defaultResult.issues.map((issue) => issue.ruleId), contains('deposit-amount'));
      expect(changed.issues.map((issue) => issue.ruleId), isNot(contains('deposit-amount')));
    });

    test('discrepancy lifecycle resolves, reopens, and keeps event history', () {
      VerificationSummary summary(VerificationIssue? issue) => VerificationSummary(
        totalChecks: issue == null ? 0 : 1,
        blocking: issue?.severity == VerificationIssueSeverity.blocking ? 1 : 0,
        warnings: issue?.severity == VerificationIssueSeverity.warning ? 1 : 0,
        statusText: 'test',
        issues: issue == null ? const [] : [issue],
      );
      const warning = VerificationIssue(
        ruleId: 'lien-information',
        severity: VerificationIssueSeverity.warning,
        message: 'Lien is missing',
        affectedField: 'lienInformation',
      );
      store.reconcileDiscrepancies(summary(warning));
      final discrepancy = store.discrepancies.single;
      expect(discrepancy.status, DiscrepancyStatus.open);
      store.reconcileDiscrepancies(summary(null));
      expect(store.discrepancies.single.status, DiscrepancyStatus.resolved);
      store.reconcileDiscrepancies(summary(warning));
      final reopened = store.discrepancies.single;
      expect(reopened.status, DiscrepancyStatus.reopened);
      expect(reopened.history.map((event) => event.action), containsAll(['Detected', 'Resolved', 'Reopened']));
      store.waiveDiscrepancy(discrepancy.id, actor: 'Officer', remark: 'Evidence reviewed');
      expect(store.discrepancies.single.status, DiscrepancyStatus.waived);
      expect(() => store.waiveDiscrepancy(discrepancy.id, actor: 'Officer', remark: ''), throwsArgumentError);
      store.reconcileDiscrepancies(summary(const VerificationIssue(
        ruleId: 'deposit-amount', severity: VerificationIssueSeverity.blocking,
        message: 'Amount differs', affectedField: 'depositAmount',
      )));
      final blocker = store.discrepancies.firstWhere((item) => item.ruleId == 'deposit-amount');
      expect(() => store.waiveDiscrepancy(blocker.id, actor: 'Officer', remark: 'Attempt'), throwsStateError);
    });
  });

  group('F2 transitions and uploaded documents', () {
    test('all transition pairs agree with the allowed-transition map', () {
      for (final from in CaseStatus.values) {
        for (final to in CaseStatus.values) {
          final allowed = ALLOWED_TRANSITIONS[from]!.contains(to);
          if (allowed) {
            expect(() => validateCaseTransition(from, to), returnsNormally);
          } else {
            expect(() => validateCaseTransition(from, to), throwsA(isA<InvalidTransitionException>()));
          }
        }
      }
    });

    test('legal transition audits; illegal transition throws; NOC guard blocks', () {
      store.createReleaseCase();
      final currentCase = store.releaseCase!;
      final count = store.auditEntries.length;
      store.transition(currentCase.caseId, CaseStatus.clearancePending, 'Officer', 'Review started');
      expect(store.releaseCase!.status, 'Clearance Pending');
      expect(store.auditEntries.length, count + 1);
      expect(() => store.transition(currentCase.caseId, CaseStatus.draft, 'Officer', 'Invalid'), throwsA(isA<InvalidTransitionException>()));
      expect(
        () => store.transition(currentCase.caseId, CaseStatus.readyForNoc, 'Officer', 'Ready'),
        throwsA(isA<InvalidTransitionException>()),
      );
      expect(store.releaseCase!.status, 'Clearance Pending');
      expect(store.auditEntries.length, count + 1);
    });

    test('upload validates type and size, hashes bytes, preserves versions and detects tamper', () async {
      expect(validateDocumentUpload(fileName: 'receipt.pdf', bytes: [1, 2, 3], mimeType: 'application/pdf'), 'application/pdf');
      expect(() => validateDocumentUpload(fileName: 'malware.exe', bytes: [1], mimeType: 'application/octet-stream'), throwsArgumentError);
      expect(() => validateDocumentUpload(fileName: 'large.pdf', bytes: List<int>.filled(5 * 1024 * 1024 + 1, 0), mimeType: 'application/pdf'), throwsArgumentError);
      store.createReleaseCase();
      final storage = MemoryLocalStorage();
      await store.initializeDocumentPersistence(storage);
      final caseId = store.releaseCase!.caseId;
      final firstBytes = <int>[1, 2, 3, 4];
      final firstHash = store.uploadRequiredDocumentBytes(
        caseId: caseId, requiredFileName: 'fdr_receipt.pdf',
        selectedFileName: 'receipt.pdf', bytes: firstBytes, mimeType: 'application/pdf',
      )!;
      expect(firstHash, checksumForDocumentBytes(firstBytes));
      final secondHash = store.uploadRequiredDocumentBytes(
        caseId: caseId, requiredFileName: 'fdr_receipt.pdf',
        selectedFileName: 'receipt-v2.pdf', bytes: [9, 8, 7], mimeType: 'application/pdf',
      )!;
      final record = store.fdrRecordForSubmission(store.releaseCase!.submissionId)!;
      final versions = record.supportedDocuments.where((item) => item.type == 'fdr_receipt.pdf').toList();
      expect(versions.map((item) => item.version), [1, 2]);
      expect(store.verifyDocumentIntegrity(versions.last.id).isValid, isTrue);
      await store.flushPersistence();
      await store.initializeDocumentPersistence(storage);
      expect(store.verifyDocumentIntegrity(versions.last.id).isValid, isTrue);
      store.replaceStoredDocumentBytes(versions.last.id, [0, 0, 0]);
      await store.flushPersistence();
      expect(store.verifyDocumentIntegrity(versions.last.id).isValid, isFalse);
      await store.initializeDocumentPersistence(storage);
      expect(store.verifyDocumentIntegrity(versions.last.id).isValid, isFalse);
      expect(secondHash, isNot(firstHash));
    });
  });

  group('F3 renewal and reminders', () {
    test('renewal creates child and removes renewed parent from deadline queue', () {
      final parent = store.fdrRecordForSubmission('FDR-2026-00124')!;
      final child = store.createRenewal(
        parentFdrReference: parent.fdrNumber,
        newFdrNumber: 'FDR-RENEWAL-TEST', bank: 'Bank', amount: 490000,
        issueDate: parent.maturityDate, tenureMonths: 24,
      );
      expect(store.fdrRecordForSubmission(parent.submissionId)!.submissionStatus, 'Renewed');
      expect(store.fdrRecordForSubmission(child.submissionId)!.parentFdrReference, parent.fdrNumber);
      expect(store.renewalLineage(parent.fdrNumber).map((item) => item.fdrNumber), containsAll([parent.fdrNumber, 'FDR-RENEWAL-TEST']));
      expect(buildOfficerActionQueue(store).where((item) => item.relatedSubmissionId == parent.submissionId && item.category.contains('Deadlines')), isEmpty);
    });

    test('renewal rejects duplicate, invalid amount, tenure, and early date', () {
      final parent = store.fdrRecordForSubmission('FDR-2026-00124')!;
      expect(() => store.createRenewal(parentFdrReference: parent.fdrNumber, newFdrNumber: parent.fdrNumber, bank: 'Bank', amount: 1, issueDate: parent.maturityDate, tenureMonths: 12), throwsArgumentError);
      expect(() => store.createRenewal(parentFdrReference: parent.fdrNumber, newFdrNumber: 'UNIQUE', bank: 'Bank', amount: 0, issueDate: parent.maturityDate, tenureMonths: 12), throwsArgumentError);
      expect(() => store.createRenewal(parentFdrReference: parent.fdrNumber, newFdrNumber: 'UNIQUE', bank: 'Bank', amount: 1, issueDate: parent.maturityDate, tenureMonths: 0), throwsArgumentError);
      expect(() => store.createRenewal(parentFdrReference: parent.fdrNumber, newFdrNumber: 'UNIQUE', bank: 'Bank', amount: 1, issueDate: '01 January 2000', tenureMonths: 12), throwsArgumentError);
    });

    test('reminders stay idempotent after reminder state reload', () async {
      final storage = MemoryLocalStorage();
      await store.initializeReminderPersistence(storage);
      final today = DateTime.now();
      final first = store.runReminderScan(today: today);
      await store.flushPersistence();
      await store.initializeReminderPersistence(storage);
      final second = store.runReminderScan(today: today);
      await store.flushPersistence();
      expect(first, greaterThan(0));
      expect(second, 0);
      expect(store.lastReminderAlreadySent, greaterThan(0));
    });

    test('institution submission collection is scoped to its institution', () {
      expect(InstitutionDemoStore.instance.submissions.every((item) => item.institutionId == 'INST-DEMO-0042'), isTrue);
    });
  });

  group('F4 audit, checksums and permissions', () {
    test('audit chain persists across reload; tamper and truncation report precise index', () async {
      final storage = MemoryLocalStorage();
      await store.initializeAuditPersistence(storage);
      store.appendAuditEntry(action: 'persist-test', associatedId: 'S', actorRole: 'Officer');
      await store.flushPersistence();
      await store.initializeAuditPersistence(storage);
      expect(store.auditIntegrity?.isValid, isTrue);
      final originalLength = store.auditEntries.length;
      await store.tamperPersistedAuditRecord();
      expect(store.auditIntegrity?.isValid, isFalse);
      expect(store.auditIntegrity?.invalidIndex, originalLength - 1);
      expect(store.auditIntegrity?.reason, 'hash mismatch');
      await store.restoreAuditBackup();
      final raw = jsonDecode((await storage.read('aicte.auditChain'))!) as Map<String, dynamic>;
      final list = raw['entries'] as List<dynamic>;
      list.removeLast();
      await storage.write('aicte.auditChain', jsonEncode({'entries': list}));
      await store.verifyPersistedAuditChain();
      expect(store.auditIntegrity?.reason, 'truncation');
    });

    test('permission matrix covers every protected action and role', () {
      for (final action in permissionMatrix.keys) {
        for (final role in AuthRole.values) {
          expect(roleCanPerform(action, role), permissionMatrix[action]!.contains(role));
        }
      }
    });

    test('signed token rejects expiration and invalid signature', () async {
      final clock = FixedClock(DateTime.utc(2026, 1, 1));
      final auth = DemoAuthService(clock: clock);
      expect(await auth.authenticate('officer-123', 'password'), isTrue);
      final token = auth.currentClaims!.token;
      expect(auth.verifyToken(token).role, AuthRole.officer);
      expect(() => auth.verifyToken('$token-tampered'), throwsA(isA<PermissionDeniedException>()));
      clock.value = clock.value.add(const Duration(hours: 9));
      expect(() => auth.verifyToken(token), throwsA(isA<PermissionDeniedException>()));
    });
  });

  group('F5 queue, reports and CSV', () {
    test('queue deduplicates each FDR and merges reasons and categories', () {
      final queue = buildOfficerActionQueue(store);
      expect(queue.map((item) => item.relatedSubmissionId).toSet(), hasLength(queue.length));
      final critical = queue.firstWhere((item) => item.relatedSubmissionId == 'FDR-2026-00124');
      expect(critical.category, contains('Deadlines'));
      expect(critical.reason, contains('Review blocking discrepancies'));
      expect(critical.reason, contains('Monitor maturity window'));
      expect(queueTargetFor(critical), QueueTarget.deadlineDetails);
      expect(queueTargetFor(const ActionQueueItem(id: 'x', institution: 'I', reference: 'F', status: '', priority: 'High', reason: '', relatedSubmissionId: 'S', category: 'Blocking discrepancies')), QueueTarget.verificationResults);
      expect(queueTargetFor(const ActionQueueItem(id: 'x', institution: 'I', reference: 'F', status: '', priority: 'High', reason: '', relatedSubmissionId: 'S', category: 'Clearances', relatedCaseId: 'C')), QueueTarget.releaseClearances);
      expect(queueTargetFor(const ActionQueueItem(id: 'x', institution: 'I', reference: 'F', status: '', priority: 'High', reason: '', relatedSubmissionId: 'S', category: 'Corrections')), QueueTarget.correction);
    });

    test('risk reason point weights reconcile score and reports totals reconcile', () {
      final records = store.dashboardSubmissions;
      final risk = assessInstitutionRisk(records.where((item) => item.institutionId == 'INST-DEMO-0042'));
      final reasonPoints = risk.reasons.fold<int>(0, (sum, reason) {
        final match = RegExp(r'\+(\d+)').firstMatch(reason);
        return sum + (match == null ? 0 : int.parse(match.group(1)!));
      });
      expect(reasonPoints, risk.score);
      final reports = StoreReportsRepository(store);
      expect(reports.statusCounts.values.fold<int>(0, (a, b) => a + b), records.length);
      expect(statusPercentages(records).values.fold<int>(0, (a, b) => a + b), 100);
      expect(reports.depositByStatus.values.fold<int>(0, (a, b) => a + b), records.fold<int>(0, (a, item) => a + item.depositAmount));
    });

    test('CSV quotes delimiters and neutralizes formula prefixes; export writes bytes', () async {
      final csv = buildSubmissionsCsv([
        const FdrSubmission(institution: '=1+1,\nOrg', institutionId: 'I', submissionId: 'S', submittedOn: 'Today', reference: '@cmd', amount: '+2', status: SubmissionStatus.pendingReview, bankName: 'Bank'),
      ]);
      expect(csv, contains('"\'=1+1,\nOrg"'));
      expect(csv, contains('"\'@cmd"'));
      final directory = await Directory.systemTemp.createTemp('aicte-csv-');
      addTearDown(() => directory.delete(recursive: true));
      final path = await writeCsvFile('${directory.path}/report.csv', csv);
      expect(await File(path).readAsString(), csv);
    });
  });

  testWidgets('new queue and script screens keep bottom navigation without overflow', (tester) async {
    store.seedDemoCases();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const AictePortalApp());
    await tester.enterText(find.byType(TextFormField).first, 'officer-123');
    await tester.enterText(find.byType(TextFormField).last, 'demo-password');
    await tester.ensureVisible(find.text('Sign In to Officer Portal'));
    await tester.tap(find.text('Sign In to Officer Portal'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View all').first);
    await tester.tap(find.text('View all').first);
    await tester.pumpAndSettle();
    expect(find.text('Officer Action Queue'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.textContaining('Clearances').first);
    await tester.tap(find.textContaining('Clearances').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Open').first);
    await tester.pumpAndSettle();
    expect(find.text('Release / Refund Case'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: DemoScriptPage()));
    await tester.pumpAndSettle();
    expect(find.text('Three-minute workflow'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    final queueTile = find.widgetWithText(ListTile, 'Queue').last;
    await tester.tap(
      find.descendant(
        of: queueTile,
        matching: find.byIcon(Icons.arrow_forward_rounded),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Officer Action Queue'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}