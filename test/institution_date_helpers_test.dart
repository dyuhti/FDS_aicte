import 'package:flutter_test/flutter_test.dart';

import 'package:fds_aicte/institution_dashboard.dart';

void main() {
  group('addMonths', () {
    test('clamps 31 January to February', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    });

    test('preserves leap day when the target month supports it', () {
      expect(addMonths(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
    });

    test('clamps 31 August plus six months', () {
      expect(addMonths(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28));
    });

    test('handles year rollover', () {
      expect(addMonths(DateTime(2026, 11, 30), 3), DateTime(2027, 2, 28));
    });
  });

  group('monthsBetween', () {
    test('counts whole months and subtracts incomplete months', () {
      expect(monthsBetween(DateTime(2026, 1, 15), DateTime(2026, 4, 14)), 2);
      expect(monthsBetween(DateTime(2026, 1, 15), DateTime(2026, 4, 15)), 3);
    });

    test('allows month-end clamping', () {
      expect(monthsBetween(DateTime(2026, 1, 31), DateTime(2026, 2, 28)), 1);
    });
  });
}
