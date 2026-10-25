import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fds_aicte/main.dart';
import 'package:fds_aicte/officer_dashboard.dart';

void main() {
  setUp(DemoFdrPortalStore.instance.resetDemoData);

  test('shared selectors reconcile demo submissions', () {
    final records = const MockOfficerDashboardRepository().submissions;

    expect(institutions(records), hasLength(3));
    expect(
      institutions(records).fold<int>(
        0,
        (sum, institution) =>
            sum + submissionsForInstitution(records, institution.id).length,
      ),
      totalSubmissions(records),
    );
    expect(
      totalDepositByStatus(
        records,
      ).values.fold<int>(0, (sum, value) => sum + value),
      records.fold<int>(0, (sum, record) => sum + record.depositAmount),
    );
    expect(
      statusPercentages(
        records,
      ).values.fold<int>(0, (sum, value) => sum + value),
      100,
    );
  });

  testWidgets('registry shows institutions and filters by name', (
    tester,
  ) async {
    await _login(tester);
    await tester.tap(find.text('Institutions'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('institution:INST-DEMO-0042')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('institution:INST-00125')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('institution:INST-00126')),
      findsOneWidget,
    );
    expect(find.text('4 submissions'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'National');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('institution:INST-00125')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('institution:INST-DEMO-0042')),
      findsNothing,
    );
  });

  testWidgets('reports renders shared summary and export action', (
    tester,
  ) async {
    await _login(tester);
    await tester.ensureVisible(find.text('Reports'));
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();

    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Total Submissions'), findsOneWidget);
    expect(find.text('Status Distribution'), findsOneWidget);
    expect(find.text('Deposit by Bank'), findsOneWidget);
    expect(find.text('Export Report'), findsOneWidget);

    await tester.ensureVisible(find.text('Export Report'));
    await tester.tap(find.text('Export Report'));
    await tester.pump();
    expect(find.textContaining('CSV report copied'), findsOneWidget);
  });
}

Future<void> _login(WidgetTester tester) async {
  await tester.pumpWidget(const AictePortalApp());
  await tester.enterText(find.byType(TextFormField).first, 'officer-123');
  await tester.enterText(find.byType(TextFormField).last, 'demo-password');
  await tester.ensureVisible(find.text('Sign In to Officer Portal'));
  await tester.tap(find.text('Sign In to Officer Portal'));
  await tester.pumpAndSettle();
}
