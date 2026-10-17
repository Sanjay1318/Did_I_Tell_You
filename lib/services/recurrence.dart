/// How often a reminder repeats. Stored on a memory as one of [values], or
/// null for a reminder that fires once.
class Recurrence {
  static const String daily = 'daily';
  static const String weekly = 'weekly';
  static const String monthly = 'monthly';

  static const List<String> values = [daily, weekly, monthly];

  static bool isValid(String? value) => value == null || values.contains(value);

  static String label(String? value) {
    switch (value) {
      case daily:
        return 'Every day';
      case weekly:
        return 'Every week';
      case monthly:
        return 'Every month';
      default:
        return 'Does not repeat';
    }
  }

  /// The first scheduled time after [now], counting forward from [base] in
  /// steps of the recurrence. If [base] is already after [now]
  /// it is returned unchanged. Monthly reminders keep their day of the month,
  /// or the last day of a shorter month (the 31st becomes the 30th, or the
  /// 28th/29th in February), and go back to the original day afterwards.
  static DateTime next(DateTime base, String recurrence, {DateTime? now}) {
    final current = now ?? DateTime.now();
    var step = 0;
    var candidate = base;
    while (!candidate.isAfter(current) && step < 10000) {
      step++;
      candidate = _nth(base, recurrence, step);
    }
    return candidate;
  }

  static DateTime _nth(DateTime base, String recurrence, int step) {
    switch (recurrence) {
      case daily:
        return DateTime(base.year, base.month, base.day + step, base.hour,
            base.minute);
      case weekly:
        return DateTime(base.year, base.month, base.day + 7 * step, base.hour,
            base.minute);
      case monthly:
        final monthIndex = base.month - 1 + step;
        final year = base.year + monthIndex ~/ 12;
        final month = monthIndex % 12 + 1;
        final lastDay = DateTime(year, month + 1, 0).day;
        final day = base.day > lastDay ? lastDay : base.day;
        return DateTime(year, month, day, base.hour, base.minute);
      default:
        throw ArgumentError.value(recurrence, 'recurrence', 'unknown');
    }
  }
}
