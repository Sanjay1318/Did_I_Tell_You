class DuplicateDetector {
  static double _jaccardSimilarity(Set<String> set1, Set<String> set2) {
    if (set1.isEmpty && set2.isEmpty) return 0.0;
    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;
    if (union == 0) return 0.0;
    return intersection / union;
  }

  static Set<String> _tokenize(String text) {
    return text.toLowerCase().split(RegExp(r'\s+')).toSet();
  }

  static bool isDuplicate(String newText, String existingText) {
    final tokens1 = _tokenize(newText);
    final tokens2 = _tokenize(existingText);
    final similarity = _jaccardSimilarity(tokens1, tokens2);
    return similarity > 0.6;
  }

  static bool isSimilar(String newText, String existingText) {
    final tokens1 = _tokenize(newText);
    final tokens2 = _tokenize(existingText);
    final similarity = _jaccardSimilarity(tokens1, tokens2);
    return similarity > 0.35 && similarity <= 0.6;
  }

  // Lower-cases the text, treats the curly apostrophe as a straight one, and
  // reduces it to space-separated words padded with a space on both sides, so a
  // phrase can be matched as whole words ("not" must not match "notebook").
  static String _normalize(String text) {
    final cleaned = text
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll(RegExp(r"[^a-z0-9' ]+"), ' ');
    final words = cleaned.split(' ').where((word) => word.isNotEmpty);
    return ' ${words.join(' ')} ';
  }

  static bool mightContradict(String newText, String existingText) {
    final negations = [
      'not',
      "don't",
      'doesn\'t',
      'no longer',
      'stopped',
      'changed',
      'moved'
    ];
    final normalizedNew = _normalize(newText);
    final normalizedExisting = _normalize(existingText);
    for (final neg in negations) {
      if (normalizedNew.contains(' $neg ') ||
          normalizedExisting.contains(' $neg ')) {
        return true;
      }
    }
    return _jaccardSimilarity(_tokenize(newText), _tokenize(existingText)) >
        0.25;
  }
}
