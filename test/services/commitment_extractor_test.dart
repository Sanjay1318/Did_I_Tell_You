import 'package:did_i_tell_you/services/commitment_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommitmentExtractor.extract', () {
    test("recognizes \"I'll ...\" and removes the trailing date word", () {
      final result = CommitmentExtractor.extract("I'll send the resume tomorrow");
      expect(result, isNotNull);
      expect(result!.action, 'send the resume');
      expect(result.status, 'pending');
    });

    test('recognizes "I will ..."', () {
      expect(CommitmentExtractor.extract('I will call the bank today')?.action,
          'call the bank');
    });

    test('recognizes "I need to ..."', () {
      expect(CommitmentExtractor.extract('I need to renew my passport')?.action,
          'renew my passport');
    });

    test('recognizes "I have to ..."', () {
      expect(
        CommitmentExtractor.extract('I have to submit the report tonight')
            ?.action,
        'submit the report',
      );
    });

    test('recognizes "remind me to ..."', () {
      expect(CommitmentExtractor.extract('Remind me to buy milk')?.action,
          'buy milk');
    });

    test('recognizes "plan to ..."', () {
      expect(CommitmentExtractor.extract('We plan to visit Goa')?.action,
          'visit Goa');
    });

    test('matches case-insensitively and keeps the original case of the action',
        () {
      expect(CommitmentExtractor.extract("I'LL CALL MOM")?.action, 'CALL MOM');
    });

    test('ignores surrounding whitespace', () {
      expect(CommitmentExtractor.extract("  I'll pay rent  ")?.action,
          'pay rent');
    });

    test('returns null for text that is not a commitment', () {
      expect(CommitmentExtractor.extract('I lent Rahul 500 rupees'), isNull);
    });

    test('returns null for an empty string', () {
      expect(CommitmentExtractor.extract(''), isNull);
    });

    test('returns null when nothing follows the trigger phrase', () {
      expect(CommitmentExtractor.extract('I will'), isNull);
    });

    test('returns null when only a date word follows the trigger phrase', () {
      expect(CommitmentExtractor.extract("I'll tomorrow"), isNull);
    });

    test('recognizes a curly apostrophe from phone keyboards', () {
      expect(CommitmentExtractor.extract('I’ll call Mom')?.action,
          'call Mom');
    });

    test('a curly apostrophe still strips the trailing date word', () {
      expect(
        CommitmentExtractor.extract('I’ll send the resume tomorrow')
            ?.action,
        'send the resume',
      );
    });
  });

  group('Commitment', () {
    test('defaults to pending status', () {
      const commitment = Commitment(action: 'send the resume');
      expect(commitment.status, 'pending');
    });
  });
}
