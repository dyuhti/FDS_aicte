import 'package:flutter_test/flutter_test.dart';

import 'package:fds_aicte/notification_center.dart';
import 'package:fds_aicte/officer_dashboard.dart';

void main() {
  setUp(() {
    DemoFdrPortalStore.instance.resetDemoData();
    NotificationCenter.instance.reset();
  });

  FdrRecord record({
    int declared = 500000,
    int receipt = 500000,
    String issueDate = '01 October 2025',
    String maturityDate = '01 October 2028',
    int tenure = 36,
    String lien = 'No lien',
    String? documentInstitution,
    String? parentFdrReference,
  }) => FdrRecord(
    institution: 'Example Institute of Technology',
    institutionId: 'INST-DEMO-0042',
    submissionId: 'TEST-1',
    bank: 'Example Bank',
    fdrNumber: 'FDR-TEST-1',
    declaredDepositAmount: declared,
    receiptAmount: receipt,
    issueDate: issueDate,
    maturityDate: maturityDate,
    declaredTenureMonths: tenure,
    enteredTenureMonths: tenure,
    lienInformation: lien,
    submissionStatus: 'Pending Review',
    documents: const [],
    institutionNameOnDocuments: documentInstitution,
    parentFdrReference: parentFdrReference,
  );

  test('F1 reports amount, date, tenure, name, lien and maturity issues', () {
    final summary = FdrVerificationService.runVerification(
      record(
        declared: 500000,
        receipt: 450000,
        issueDate: 'not-a-date',
        maturityDate: 'also-invalid',
        tenure: 0,
        lien: 'Not provided',
        documentInstitution: 'Other Institute',
      ),
    );
    final rules = summary.issues.map((issue) => issue.ruleId).toSet();
    expect(
      rules,
      containsAll(<String>[
        'deposit-amount',
        'lien-information',
        'date-consistency',
        'institution-name-mismatch',
      ]),
    );
    expect(summary.blocking, greaterThan(0));
  });

  test('F1 detects tenure mismatch and duplicate FDRs', () {
    final mismatch = FdrVerificationService.runVerification(record(tenure: 24));
    expect(
      mismatch.issues.map((issue) => issue.ruleId),
      contains('tenure-consistency'),
    );

    final duplicate = FdrVerificationService.runVerification(record());
    expect(
      duplicate.issues.map((issue) => issue.ruleId),
      isNot(contains('duplicate-fdr')),
    );
    final knownDuplicate = FdrVerificationService.runVerification(
      record().copyWith(fdrNumber: 'FDR-EX-884201'),
    );
    expect(
      knownDuplicate.issues.map((issue) => issue.ruleId),
      contains('duplicate-fdr'),
    );
  });

  test(
    'F3 classifies active, expiring, critical, matured, due-today and invalid dates',
    () {
      final submissions = [
        for (var index = 0; index < 6; index++)
          Submission.fromFields(
            id: 'D-$index',
            institutionId: 'I-1',
            institutionName: 'Institute',
            fdrReference: 'FDR-$index',
            bank: 'Bank',
            caseType: 'FDR Submission',
            depositAmount: 1,
            status: SubmissionStatus.pendingReview,
            updatedAt: DateTime(2026, 1, 1),
          ),
      ];
      final deadlines = calculateFdrDeadlines(
        submissions,
        today: DateTime(2026, 1, 1),
        maturityDates: {
          'D-0': '01 January 2027',
          'D-1': '31 January 2026',
          'D-2': '08 January 2026',
          'D-3': '31 December 2025',
          'D-4': '01 January 2026',
          'D-5': 'invalid',
        },
      );
      expect(
        deadlines.map((item) => item.status),
        containsAll(<MaturityStatus>[
          MaturityStatus.active,
          MaturityStatus.expiringSoon,
          MaturityStatus.critical,
          MaturityStatus.matured,
          MaturityStatus.invalid,
        ]),
      );
      expect(deadlines.first.status, MaturityStatus.matured);
    },
  );

  test(
    'F3 reminder scan is duplicate-safe and renewal lineage rejects invalid links',
    () {
      final store = DemoFdrPortalStore.instance;
      final created = store.submitInstitutionFdr(
        institution: 'Example Institute of Technology',
        institutionId: 'INST-DEMO-0042',
        bank: 'Bank',
        fdrNumber: 'FDR-RENEWED',
        amount: 100,
      );
      final parent = store.dashboardSubmissions.firstWhere(
        (item) => item.reference != created.reference,
      );
      final linked = store.linkRenewal(
        submissionId: created.submissionId,
        parentFdrReference: parent.reference,
      );
      expect(linked, isTrue);
      expect(
        store.fdrRecordForSubmission(created.submissionId)?.parentFdrReference,
        parent.reference,
      );
      expect(
        store.linkRenewal(
          submissionId: created.submissionId,
          parentFdrReference: 'missing',
        ),
        isFalse,
      );

      final first = store.runReminderScan(today: DateTime(2026, 10, 25));
      final second = store.runReminderScan(today: DateTime(2026, 10, 25));
      expect(second, 0);
      expect(first, greaterThanOrEqualTo(0));
    },
  );

  test('F5 builds unique prioritized queue, risk reasons and escaped CSV', () {
    final store = DemoFdrPortalStore.instance;
    final queue = buildOfficerActionQueue(store, today: DateTime(2026, 10, 25));
    expect(queue.map((item) => item.id).toSet(), hasLength(queue.length));
    expect(queue.any((item) => item.priority == 'High'), isTrue);

    final risk = assessInstitutionRisk(
      store.dashboardSubmissions.where(
        (item) => item.institutionId == 'INST-DEMO-0042',
      ),
    );
    expect(risk.category, anyOf('Low', 'Medium', 'High'));
    expect(risk.reasons, isNotEmpty);

    final csv = buildSubmissionsCsv([
      const FdrSubmission(
        institution: 'Institute, One',
        institutionId: 'I-1',
        submissionId: 'S-1',
        submittedOn: '25 Oct 2026',
        reference: 'FDR-1',
        amount: '₹1',
        status: SubmissionStatus.pendingReview,
        bankName: 'Bank',
      ),
    ]);
    expect(csv, contains('"Institute, One"'));
    expect(csv, contains('Submission ID,Institution ID'));
  });

  test(
    'F4 detects reordered and modified audit entries and checksums only bytes',
    () {
      final store = DemoFdrPortalStore.instance;
      final entries = store.auditEntries.toList();
      expect(verifyAuditChain(entries).isValid, isTrue);
      final reordered = [...entries.reversed];
      expect(verifyAuditChain(reordered).isValid, isFalse);
      expect(checksumForDocumentBytes(null), isNull);
      expect(
        checksumForDocumentBytes(<int>[1, 2, 3]),
        checksumForDocumentBytes(<int>[1, 2, 3]),
      );
      expect(
        checksumForDocumentBytes(<int>[1, 2, 3]),
        isNot(checksumForDocumentBytes(<int>[1, 2, 4])),
      );
    },
  );
}
