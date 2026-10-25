import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fds_aicte/institution_dashboard.dart';
import 'package:fds_aicte/main.dart';
import 'package:fds_aicte/notification_center.dart';
import 'package:fds_aicte/officer_dashboard.dart';

void main() {
  setUp(() {
    InstitutionDemoStore.instance.resetDemoData();
    NotificationCenter.instance.reset();
  });

  test('workflow submission creates one notification per recipient and stays private', () {
    final store = InstitutionDemoStore.instance;
    store.addSubmission(
      fdrNumber: 'FDR-TEST-1001',
      bankName: 'Test Bank',
      amount: 200000,
    );
    final officer = NotificationCenter.instance.forRecipient(
      NotificationRecipientRole.officer,
    );
    final institution = NotificationCenter.instance.forRecipient(
      NotificationRecipientRole.institution,
      recipientId: 'INST-DEMO-0042',
    );
    expect(officer.where((item) => item.relatedId?.startsWith('FDR-') ?? false), hasLength(2));
    expect(institution.any((item) => item.title == 'FDR Submission Received'), isTrue);
    expect(
      NotificationCenter.instance.forRecipient(
        NotificationRecipientRole.institution,
        recipientId: 'INST-OTHER',
      ),
      isEmpty,
    );
  });

  test('read state, mark all, filters, and duplicate prevention work', () {
    final center = NotificationCenter.instance;
    center.add(
      recipientRole: NotificationRecipientRole.officer,
      title: 'Approval',
      message: 'Approved',
      category: NotificationCategory.approval,
      eventKey: 'approval-1',
    );
    center.add(
      recipientRole: NotificationRecipientRole.officer,
      title: 'Approval duplicate',
      message: 'Ignored',
      category: NotificationCategory.approval,
      eventKey: 'approval-1',
    );
    expect(center.unreadCount(NotificationRecipientRole.officer), 2);
    center.markRead('approval-1');
    expect(center.unreadCount(NotificationRecipientRole.officer), 1);
    expect(
      center.forRecipient(NotificationRecipientRole.officer, category: NotificationCategory.approval),
      hasLength(1),
    );
    center.markAllRead(NotificationRecipientRole.officer);
    expect(center.unreadCount(NotificationRecipientRole.officer), 0);
  });

  test('clarification and institution response persist on the shared case', () {
    final institutionStore = InstitutionDemoStore.instance;
    institutionStore.addReleaseRequest(
      fdrNumber: 'FDR-EIT-771530',
      requestType: 'Progressive Closure',
      amount: 100000,
      reason: 'Clarification flow',
      caseType: 'Progressive Closure',
    );
    final created = institutionStore.submissions.first;
    final officerStore = DemoFdrPortalStore.instance;
    officerStore.selectReleaseCase(created.caseId!);
    officerStore.updateClearanceStatus(
      'Grievance Redressal Cell',
      'Clarification Requested',
      remark: 'Please provide the grievance closure details.',
    );

    final sharedCase = institutionStore.releaseCaseForSubmission(created.id)!;
    final clearance = sharedCase.clearances.firstWhere(
      (item) => item.name == 'Grievance Redressal Cell',
    );
    expect(clearance.status, 'Clarification Requested');
    expect(clearance.remarkHistory.single.text, contains('grievance closure'));
    expect(
      NotificationCenter.instance.forRecipient(
        NotificationRecipientRole.institution,
        recipientId: 'INST-DEMO-0042',
      ).any((item) => item.category == NotificationCategory.clarification),
      isTrue,
    );

    officerStore.respondToClarification(
      submissionId: created.id,
      clearanceName: 'Grievance Redressal Cell',
      response: 'The closure report is ready for review.',
    );
    final responded = institutionStore.releaseCaseForSubmission(created.id)!;
    final respondedClearance = responded.clearances.firstWhere(
      (item) => item.name == 'Grievance Redressal Cell',
    );
    expect(respondedClearance.status, 'Response Submitted');
    expect(respondedClearance.response, contains('closure report'));
    expect(
      NotificationCenter.instance.forRecipient(NotificationRecipientRole.officer)
          .any((item) => item.title == 'Clarification Response Received'),
      isTrue,
    );
  });

  testWidgets('both portals open Notifications and officer Profile displays data', (tester) async {
    await tester.pumpWidget(const AictePortalApp());
    await tester.enterText(find.byType(TextFormField).first, 'officer-123');
    await tester.enterText(find.byType(TextFormField).last, 'demo-password');
    await tester.ensureVisible(find.text('Sign In to Officer Portal'));
    await tester.tap(find.text('Sign In to Officer Portal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('New FDR Submission'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Officer Information'), findsOneWidget);
    expect(find.text('AICTE Officer'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Activity Summary'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Activity Summary'), findsOneWidget);
  });
}
