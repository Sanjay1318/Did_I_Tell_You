import 'package:did_i_tell_you/services/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('labels and validation', () {
    test('has a readable label for each choice', () {
      expect(Recurrence.label(null), 'Does not repeat');
      expect(Recurrence.label('daily'), 'Every day');
      expect(Recurrence.label('weekly'), 'Every week');
      expect(Recurrence.label('monthly'), 'Every month');
    });

    test('accepts null and the three known values only', () {
      expect(Recurrence.isValid(null), isTrue);
      for (final value in Recurrence.values) {
        expect(Recurrence.isValid(value), isTrue);
      }
      expect(Recurrence.isValid('hourly'), isFalse);
      expect(Recurrence.isValid(''), isFalse);
    });
  });

  group('next', () {
    test('returns the base time itself if it is still ahead', () {
      final base = DateTime(2026, 3, 10, 9, 30);
      final now = DateTime(2026, 3, 1);
      for (final value in Recurrence.values) {
        expect(Recurrence.next(base, value, now: now), base);
      }
    });

    test('daily moves forward to the next day at the same time', () {
      final base = DateTime(2026, 1, 1, 10);
      final now = DateTime(2026, 1, 3, 12);
      expect(Recurrence.next(base, 'daily', now: now),
          DateTime(2026, 1, 4, 10));
    });

    test('daily later the same day if the time has not passed yet', () {
      final base = DateTime(2026, 1, 1, 10);
      final now = DateTime(2026, 1, 3, 8);
      expect(Recurrence.next(base, 'daily', now: now),
          DateTime(2026, 1, 3, 10));
    });

    test('weekly keeps the weekday', () {
      final base = DateTime(2026, 1, 1, 10); // a Thursday
      final now = DateTime(2026, 1, 20);
      final next = Recurrence.next(base, 'weekly', now: now);
      expect(next, DateTime(2026, 1, 22, 10));
      expect(next.weekday, base.weekday);
    });

    test('monthly keeps the day of the month', () {
      final base = DateTime(2026, 1, 15, 18, 45);
      final now = DateTime(2026, 4, 16);
      expect(Recurrence.next(base, 'monthly', now: now),
          DateTime(2026, 5, 15, 18, 45));
    });

    test('monthly uses the last day of a shorter month', () {
      final base = DateTime(2026, 1, 31, 10);
      expect(Recurrence.next(base, 'monthly', now: DateTime(2026, 2, 1)),
          DateTime(2026, 2, 28, 10));
      expect(Recurrence.next(base, 'monthly', now: DateTime(2028, 2, 1)),
          DateTime(2028, 2, 29, 10)); // a leap year
    });

    test('monthly goes back to the original day after a short month', () {
      final base = DateTime(2026, 1, 31, 10);
      expect(Recurrence.next(base, 'monthly', now: DateTime(2026, 3, 1)),
          DateTime(2026, 3, 31, 10));
    });

    test('monthly rolls over into the next year', () {
      final base = DateTime(2026, 12, 15, 10);
      expect(Recurrence.next(base, 'monthly', now: DateTime(2026, 12, 20)),
          DateTime(2027, 1, 15, 10));
    });

    test('rejects an unknown recurrence', () {
      expect(
        () => Recurrence.next(DateTime(2026, 1, 1), 'hourly',
            now: DateTime(2026, 2, 1)),
        throwsArgumentError,
      );
    });
  });
}
