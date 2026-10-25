import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fds_aicte/main.dart';
import 'package:fds_aicte/officer_dashboard.dart';

void main() {
  testWidgets('login screen renders with AICTE Officer selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AictePortalApp());

    expect(find.text('AICTE'), findsOneWidget);
    expect(find.text('Welcome, Officer'), findsOneWidget);
    expect(find.text('AICTE OFFICER PORTAL'), findsOneWidget);
    expect(find.text('Institution'), findsOneWidget);
    expect(find.text('AICTE Officer'), findsOneWidget);
    expect(find.text('Register Institution'), findsNothing);

    final selectedRole = tester.widget<Semantics>(
      find.ancestor(
        of: find.text('AICTE Officer'),
        matching: find.byType(Semantics),
      ).first,
    );
    expect(selectedRole.properties.selected, isTrue);
    expect(find.text('Official Officer Access'), findsOneWidget);
    expect(find.text('Authorized AICTE personnel only'), findsOneWidget);
  });

  testWidgets('empty sign in shows inline validation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AictePortalApp());
    await tester.ensureVisible(find.text('Sign In to Officer Portal'));
    await tester.tap(find.text('Sign In to Officer Portal'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your registered officer ID'), findsNWidgets(2));
    expect(find.text('Enter your password'), findsNWidgets(2));
  });

  testWidgets('malformed email user ID shows inline validation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AictePortalApp());
    await tester.enterText(find.byType(TextFormField).first, 'user@invalid');
    await tester.ensureVisible(find.text('Sign In to Officer Portal'));
    await tester.tap(find.text('Sign In to Officer Portal'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a valid email address or registered ID'),
      findsOneWidget,
    );
  });

  testWidgets('valid credentials enter the seeded FDR verification flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AictePortalApp());
    await tester.enterText(find.byType(TextFormField).first, 'officer-123');
    await tester.enterText(find.byType(TextFormField).last, 'demo-password');
    await tester.ensureVisible(find.text('Sign In to Officer Portal'));
    await tester.tap(find.text('Sign In to Officer Portal'));
    await tester.pumpAndSettle();

    expect(find.text('AICTE Officer Portal'), findsOneWidget);
    expect(find.text('Welcome back, Officer'), findsOneWidget);
    expect(find.textContaining('Demo mode'), findsOneWidget);
    expect(find.text('Pending Verification'), findsOneWidget);
    expect(find.text('Deposit  ₹5,00,000', findRichText: true), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Review').first);
    await tester.tap(find.widgetWithText(TextButton, 'Review').first);
    await tester.pumpAndSettle();

    expect(find.text('FDR Verification'), findsOneWidget);
    expect(find.text('Example Institute of Technology'), findsOneWidget);
    expect(find.textContaining('FDR-EX-884201'), findsOneWidget);
    expect(find.text('Institution Details'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Officer profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Officer'), findsOneWidget);
  });

  testWidgets('Home refreshes after corrected FDR verification', (tester) async {
    DemoFdrPortalStore.instance.resetDemoData();
    await tester.pumpWidget(const AictePortalApp());
    await tester.enterText(find.byType(TextFormField).first, 'officer-123');
    await tester.enterText(find.byType(TextFormField).last, 'demo-password');
    await tester.ensureVisible(find.text('Sign In to Officer Portal'));
    await tester.tap(find.text('Sign In to Officer Portal'));
    await tester.pumpAndSettle();

    final pendingMetric = find.byKey(const ValueKey('metric:Pending Review'));
    expect(find.descendant(of: pendingMetric, matching: find.text('3')), findsOneWidget);
    expect(find.text('Submission  FDR-2026-00124', findRichText: true), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Review').first);
    await tester.tap(find.widgetWithText(TextButton, 'Review').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Run Verification'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Run Verification'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Correct Details'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Correct Details'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'FDR-EX-884201-CORRECTED');
    await tester.enterText(find.byType(TextFormField).at(1), '450000');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save Corrected Details'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save Corrected Details'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Run Verification'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Run Verification'));
    await tester.pumpAndSettle();
    expect(
      const MockOfficerDashboardRepository().summary['Pending Review'],
      2,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, Officer'), findsOneWidget);
    expect(find.descendant(of: pendingMetric, matching: find.text('2')), findsOneWidget);
    expect(find.text('Submission  FDR-2026-00124', findRichText: true), findsNothing);
    expect(find.text('Submission  FDR-2026-00125', findRichText: true), findsOneWidget);
    expect(find.text('Submission  FDR-2026-00126', findRichText: true), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
  });

  testWidgets('Approved overview opens the filtered approved submission list', (tester) async {
    final store = DemoFdrPortalStore.instance;
    store.resetDemoData();
    store.createReleaseCase();
    store.updateReleaseCaseType('Merger');
    store.updateClearanceStatus('Grievance Redressal Cell', 'Cleared');
    store.updateClearanceStatus('Vigilance Cell', 'Cleared');
    store.approveMergerInDemoMode();

    await tester.pumpWidget(const AictePortalApp());
    await tester.enterText(find.byType(TextFormField).first, 'officer-123');
    await tester.enterText(find.byType(TextFormField).last, 'demo-password');
    await tester.ensureVisible(find.text('Sign In to Officer Portal'));
    await tester.tap(find.text('Sign In to Officer Portal'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('metric:Approved')));
    await tester.pumpAndSettle();

    expect(find.text('Approved Submissions'), findsOneWidget);
    expect(find.text('Approved (1)'), findsOneWidget);
    expect(find.text('Submission  FDR-2026-00124', findRichText: true), findsOneWidget);
    expect(find.text('FDR reference  FDR-EX-884201', findRichText: true), findsOneWidget);
    expect(find.text('Action  Demo approval by Demo Officer', findRichText: true), findsOneWidget);
    expect(find.text('Pending Review (2)'), findsOneWidget);

    await tester.tap(find.text('Pending Review (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Submission  FDR-2026-00124', findRichText: true), findsNothing);
    expect(find.text('Submission  FDR-2026-00125', findRichText: true), findsOneWidget);
  });

  testWidgets('password is hidden until visibility is toggled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AictePortalApp());

    var passwordField = tester.widget<TextField>(find.byType(TextField).last);
    expect(passwordField.obscureText, isTrue);

    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    passwordField = tester.widget<TextField>(find.byType(TextField).last);
    expect(passwordField.obscureText, isFalse);
  });
}
