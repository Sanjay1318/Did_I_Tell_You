import 'package:did_i_tell_you/services/entity_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EntityExtractor.extractPerson', () {
    test('finds a known name and capitalizes it', () {
      expect(EntityExtractor.extractPerson('I lent Rahul 500 rupees'), 'Rahul');
    });

    test('ignores punctuation around the name', () {
      expect(EntityExtractor.extractPerson('Call Priya!'), 'Priya');
      expect(EntityExtractor.extractPerson('Met amit, then left'), 'Amit');
    });

    test('returns the first known name when several appear', () {
      expect(EntityExtractor.extractPerson('priya and amit came'), 'Priya');
    });

    test('returns null when no name is present', () {
      expect(EntityExtractor.extractPerson('bought milk today'), isNull);
    });

    test('returns null for an empty string', () {
      expect(EntityExtractor.extractPerson(''), isNull);
    });

    // Characterization test: the text is lower-cased before the capitalized-word
    // fallback runs, so names outside the built-in list are never detected.
    // When that is fixed, update this expectation.
    test('does not detect names missing from the built-in list (current behavior)',
        () {
      expect(EntityExtractor.extractPerson('Ramya called me'), isNull);
    });
  });

  group('EntityExtractor.extractAmount', () {
    test('parses the rupee symbol with thousands separators', () {
      expect(EntityExtractor.extractAmount('Paid ₹1,500 for lunch'), 1500.0);
    });

    test('parses Indian digit grouping', () {
      expect(EntityExtractor.extractAmount('Loan of ₹1,00,000'), 100000.0);
    });

    test('parses Rs. prefix', () {
      expect(EntityExtractor.extractAmount('Rs. 250 for auto'), 250.0);
    });

    test('parses INR prefix with decimals', () {
      expect(EntityExtractor.extractAmount('INR 2,000.50 received'), 2000.5);
    });

    test('parses "<number> rupees"', () {
      expect(EntityExtractor.extractAmount('Gave Priya 500 rupees'), 500.0);
    });

    test('parses "<number> rs"', () {
      expect(EntityExtractor.extractAmount('Tea cost 2500 rs'), 2500.0);
    });

    test('returns null when there is no amount', () {
      expect(EntityExtractor.extractAmount('Met Priya at the mall'), isNull);
    });

    test('returns null for a bare number with no currency', () {
      expect(EntityExtractor.extractAmount('Room number 504'), isNull);
    });

    test('does not read "rs" inside another word as currency', () {
      expect(EntityExtractor.extractAmount('The shop offers 20 discounts'),
          isNull);
    }, skip: 'Known bug: the "rs" prefix has no word boundary, so "offers 20" '
        'is parsed as an amount of 20.');
  });

  group('EntityExtractor.extractDate', () {
    // The extractor works relative to DateTime.now(), so these tests compare
    // against "now" with a small tolerance instead of fixed dates.
    int minutesFromNow(String isoDate) =>
        DateTime.parse(isoDate).difference(DateTime.now()).inMinutes;

    test('"tomorrow" is about 24 hours from now', () {
      final result = EntityExtractor.extractDate('send the file tomorrow');
      expect(result, isNotNull);
      expect(minutesFromNow(result!), inInclusiveRange(1438, 1440));
    });

    test('"yesterday" is about 24 hours ago', () {
      final result = EntityExtractor.extractDate('I paid him yesterday');
      expect(result, isNotNull);
      expect(minutesFromNow(result!), inInclusiveRange(-1442, -1440));
    });

    test('"today" is now', () {
      final result = EntityExtractor.extractDate('call the bank today');
      expect(result, isNotNull);
      expect(minutesFromNow(result!), inInclusiveRange(-1, 0));
    });

    test('"on <weekday>" resolves to that weekday within the next 7 days', () {
      final result = EntityExtractor.extractDate('Dentist appointment on Friday');
      expect(result, isNotNull);
      final parsed = DateTime.parse(result!);
      expect(parsed.weekday, DateTime.friday);
      expect(parsed.difference(DateTime.now()).inDays, inInclusiveRange(0, 6));
    });

    test('parses "Month day" with an ordinal suffix', () {
      final result = EntityExtractor.extractDate('Birthday party on December 25th');
      expect(result, isNotNull);
      final parsed = DateTime.parse(result!);
      expect(parsed.month, 12);
      expect(parsed.day, 25);
    });

    test('parses abbreviated month names', () {
      final result = EntityExtractor.extractDate('Flight on Mar 3');
      expect(result, isNotNull);
      final parsed = DateTime.parse(result!);
      expect(parsed.month, 3);
      expect(parsed.day, 3);
    });

    test('parses dd/mm/yyyy', () {
      final result = EntityExtractor.extractDate('Submit by 15/03/2099');
      expect(result, isNotNull);
      final parsed = DateTime.parse(result!);
      expect(parsed.year, 2099);
      expect(parsed.month, 3);
      expect(parsed.day, 15);
    });

    test('expands two-digit years into the 2000s', () {
      final result = EntityExtractor.extractDate('due 01/02/99');
      expect(result, isNotNull);
      final parsed = DateTime.parse(result!);
      expect(parsed.year, 2099);
      expect(parsed.month, 2);
      expect(parsed.day, 1);
    });

    test('rejects an impossible numeric date', () {
      expect(EntityExtractor.extractDate('call 32/13/2026'), isNull);
    });

    test('rejects an impossible day in "Month day"', () {
      expect(EntityExtractor.extractDate('Feb 45'), isNull);
    });

    test('returns null when there is no date', () {
      expect(EntityExtractor.extractDate('Bought groceries'), isNull);
    });
  });

  group('EntityExtractor.extractLocation', () {
    test('finds a capitalized place after "at"', () {
      expect(EntityExtractor.extractLocation('Met him at Starbucks'),
          'Starbucks');
    });

    test('keeps multi-word place names together', () {
      expect(EntityExtractor.extractLocation('I parked the car at Forum Mall'),
          'Forum Mall');
    });

    test('finds a place after "in"', () {
      expect(EntityExtractor.extractLocation('Met Priya in Hyderabad yesterday'),
          'Hyderabad');
    });

    test('returns null for lower-case places', () {
      expect(EntityExtractor.extractLocation('parked at the mall'), isNull);
    });

    test('returns null when there is no location', () {
      expect(EntityExtractor.extractLocation('Remember to buy milk'), isNull);
    });
  });

  group('EntityExtractor.extractKeywords', () {
    test('keeps meaningful words and drops short ones', () {
      expect(
        EntityExtractor.extractKeywords('I lent Rahul 500 rupees yesterday'),
        ['lent', 'rahul', 'rupees', 'yesterday'],
      );
    });

    test('drops stop words', () {
      expect(
        EntityExtractor.extractKeywords('I forgot about that meeting'),
        ['forgot', 'meeting'],
      );
    });

    test('strips punctuation and lower-cases', () {
      expect(
        EntityExtractor.extractKeywords('Hello, World!!'),
        ['hello', 'world'],
      );
    });

    test('returns an empty list for an empty string', () {
      expect(EntityExtractor.extractKeywords(''), isEmpty);
    });
  });
}
