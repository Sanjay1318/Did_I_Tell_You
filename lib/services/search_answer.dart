import '../models/memory.dart';

/// Builds the short written answer shown above the search results.
class SearchAnswer {
  static String _count(int n) => n == 1 ? '1 memory' : '$n memories';

  static String generate(String query, List<Memory> results) {
    if (results.isEmpty) return '';
    final lower = query.toLowerCase().trim();

    if (lower.contains('who owes me') || lower.contains('who owe me')) {
      final buffer = StringBuffer();
      for (final memory in results) {
        final person = memory.person ?? 'Someone';
        final amount = memory.amount;
        if (amount != null) {
          buffer.writeln('$person owes you ₹${amount.toStringAsFixed(0)}');
        } else {
          buffer.writeln(memory.originalText);
        }
      }
      return buffer.toString().trim();
    }

    if (lower.contains('what do i know about') ||
        lower.contains('tell me about')) {
      final person = results.first.person ?? 'this person';
      return 'You have ${_count(results.length)} about $person.';
    }

    if (lower.contains('where did i park')) {
      for (final memory in results) {
        if (memory.originalText.toLowerCase().contains('park')) {
          return 'You parked: ${memory.originalText}';
        }
      }
    }

    if (lower.contains('what food does') || lower.contains('what does')) {
      for (final memory in results) {
        final text = memory.originalText.toLowerCase();
        if (text.contains('like') ||
            text.contains('love') ||
            text.contains('prefer') ||
            text.contains('favorite')) {
          return memory.originalText;
        }
      }
    }

    return 'Found ${_count(results.length)}.';
  }
}
