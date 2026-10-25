import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fds_aicte/main.dart';

void main() {
  testWidgets('debug route tree', (WidgetTester tester) async {
    await tester.pumpWidget(const AictePortalApp());
    await tester.enterText(find.byType(TextFormField).first, 'officer-123');
    await tester.enterText(find.byType(TextFormField).last, 'demo-password');
    await tester.ensureVisible(find.text('Sign In to Officer Portal'));
    await tester.tap(find.text('Sign In to Officer Portal'));
    await tester.pumpAndSettle();
    debugPrint('AFTER LOGIN');
    debugDumpApp();

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Review').first);
    await tester.tap(find.widgetWithText(TextButton, 'Review').first);
    await tester.pumpAndSettle();
    debugPrint('AFTER REVIEW');
    debugDumpApp();

    debugPrint('Has text Submitted Documents? ${find.text('Submitted Documents').evaluate().length}');
    debugPrint('Has text FDR Verification? ${find.text('FDR Verification').evaluate().length}');
    debugPrint('Has text Institution Details? ${find.text('Institution Details').evaluate().length}');
  });
}
