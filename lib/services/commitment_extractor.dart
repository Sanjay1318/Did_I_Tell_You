class Commitment {
  final String action;
  final String status;

  const Commitment({required this.action, this.status = 'pending'});
}

class CommitmentExtractor {
  static final RegExp _commitment = RegExp(
    r"\b(?:i(?:'ll| will| need to| have to)|remind me to|plan to)\s+(.+)",
    caseSensitive: false,
  );

  static Commitment? extract(String text) {
    final match = _commitment.firstMatch(text.trim());
    if (match == null) return null;
    var action = match.group(1)!.trim();
    action = action
        .replaceFirst(
            RegExp(r'\b(?:today|tomorrow|tonight)\b.*$', caseSensitive: false),
            '')
        .trim();
    return action.isEmpty ? null : Commitment(action: action);
  }
}
