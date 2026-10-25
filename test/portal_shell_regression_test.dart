import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fds_aicte/institution_dashboard.dart';
import 'package:fds_aicte/officer_dashboard.dart';
import 'package:fds_aicte/portal_foundations.dart';

void main() {
  setUp(() {
    DemoFdrPortalStore.instance.resetDemoData();
    InstitutionDemoStore.instance.resetDemoData();
  });

  test('all displayed status and severity enums have readable labels', () {
    final values = <Enum>[
      ...SubmissionStatus.values,
      ...InstitutionSubmissionStatus.values,
      ...MaturityStatus.values,
      ...VerificationIssueSeverity.values,
      ...DiscrepancyStatus.values,
      ...RuleSeverity.values,
      ...ComparisonStatus.values,
      ...CaseStatus.values,
    ];
    for (final value in values) {
      expect(value.displayLabel, isNotEmpty, reason: value.toString());
      expect(value.displayLabel, isNot(matches(RegExp(r'[a-z][A-Z]'))));
    }
    expect(SubmissionStatus.pendingReview.displayLabel, 'Pending Review');
    expect(InstitutionSubmissionStatus.actionRequired.displayLabel, 'Action Required');
    expect(SubmissionStatus.rejected.displayLabel, 'Rejected');
  });

  testWidgets('odd officer overview row spans full width at narrow scaled size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OfficerDashboardScreen(userId: 'officer-demo', onSignOut: () {}),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.3),
          ),
          child: child!,
        ),
      ),
    );
    final totalInstitutions = find.byKey(
      const ValueKey('metric:Total Institutions'),
    );
    final totalSubmissions = find.byKey(
      const ValueKey('metric:Total Submissions'),
    );
    await tester.ensureVisible(totalInstitutions);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(totalInstitutions).width,
      greaterThan(tester.getSize(totalSubmissions).width * 1.9),
    );
    final layoutFailure = tester.takeException();
    expect(layoutFailure, isNull, reason: '$layoutFailure');
  });

  testWidgets('institution attention items are cards and navigate with shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    expect(
      InstitutionDemoStore.instance.submissions.any((record) => record.issues.isNotEmpty),
      isTrue,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: InstitutionDashboardScreen(onSignOut: () {}),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Items Requiring Attention'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Items Requiring Attention'));
    await tester.pumpAndSettle();

    expect(find.text('Items Requiring Attention'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    await tester.scrollUntilVisible(
      find.textContaining('Warnings ('),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Warnings ('), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Missing supporting document'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Missing supporting document'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
    expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
    expect(find.text('actionRequired'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('FDR amount mismatch'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('FDR amount mismatch'));
    await tester.pumpAndSettle();
    expect(find.text('Submission Details'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
    expect(find.text('My Submissions'), findsWidgets);
  });
}