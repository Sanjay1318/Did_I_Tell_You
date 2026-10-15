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

    test('detects a known name written as a possessive', () {
      expect(EntityExtractor.extractPerson("Rahul's birthday is tomorrow"),
          'Rahul');
    });

    group('names missing from the built-in list', () {
      test('detected after a cue word like "lent"', () {
        expect(EntityExtractor.extractPerson('I lent Ramya 500 rupees'),
            'Ramya');
      });

      test('detected after "met", even at the start of the text', () {
        expect(EntityExtractor.extractPerson('Met Ramya at the cafe'), 'Ramya');
      });

      test('detected as a possessive', () {
        expect(EntityExtractor.extractPerson("Ramya's birthday is tomorrow"),
            'Ramya');
      });

      test('detected with a curly-apostrophe possessive', () {
        expect(
            EntityExtractor.extractPerson('Ramya’s birthday is tomorrow'),
            'Ramya');
      });

      test('detected before a verb like "said"', () {
        expect(EntityExtractor.extractPerson('Ramya said hello'), 'Ramya');
      });

      test('a capitalized sentence starter is not a person', () {
        expect(EntityExtractor.extractPerson('Bought milk today'), isNull);
      });

      test('places are not people', () {
        expect(EntityExtractor.extractPerson('Parked at Forum Mall'), isNull);
      });

      test('brands and titles are not people', () {
        expect(EntityExtractor.extractPerson('I bought it from Amazon'), isNull);
        expect(
            EntityExtractor.extractPerson('Watched Interstellar on Netflix'),
            isNull);
      });

      test('ALL-CAPS acronyms are not people', () {
        expect(EntityExtractor.extractPerson('Call EMI office'), isNull);
      });

      // Deliberate limitation: without a cue, an unknown capitalized word at
      // the start of a sentence cannot be told apart from "Bought" or "Parked".
      test('an unknown name with no cue is not detected', () {
        expect(EntityExtractor.extractPerson('Ramya called me'), isNull);
      });
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
    });

    test('still parses Rs with no space before the digits', () {
      expect(EntityExtractor.extractAmount('Paid Rs250 for tea'), 250.0);
    });
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

    group('weekday phrases', () {
      const days = {
        'monday': DateTime.monday,
        'tuesday': DateTime.tuesday,
        'wednesday': DateTime.wednesday,
        'thursday': DateTime.thursday,
        'friday': DateTime.friday,
        'saturday': DateTime.saturday,
        'sunday': DateTime.sunday,
      };

      // Whole calendar days from the date in [iso] to today (negative if the
      // date is in the future). Uses UTC midnights so daylight saving shifts
      // cannot change the answer.
      int daysBeforeToday(String iso) {
        final parsed = DateTime.parse(iso);
        final now = DateTime.now();
        return DateTime.utc(now.year, now.month, now.day)
            .difference(DateTime.utc(parsed.year, parsed.month, parsed.day))
            .inDays;
      }

      days.forEach((name, weekday) {
        test('"last $name" is the most recent $name, 1 to 7 days back', () {
          final result = EntityExtractor.extractDate('Met him last $name');
          expect(result, isNotNull);
          expect(DateTime.parse(result!).weekday, weekday);
          expect(daysBeforeToday(result), inInclusiveRange(1, 7));
        });

        test('"this $name" is that weekday, today or within the next 6 days',
            () {
          final result = EntityExtractor.extractDate('Meeting this $name');
          expect(result, isNotNull);
          expect(DateTime.parse(result!).weekday, weekday);
          expect(daysBeforeToday(result), inInclusiveRange(-6, 0));
        });
      });

      test('"last <weekday>" never lands in the future', () {
        for (final name in days.keys) {
          final result = EntityExtractor.extractDate('last $name')!;
          expect(DateTime.parse(result).isBefore(DateTime.now()), isTrue,
              reason: 'last $name');
        }
      });

      test('weekday names are matched regardless of letter case', () {
        final result = EntityExtractor.extractDate('See you LAST FRIDAY');
        expect(DateTime.parse(result!).weekday, DateTime.friday);
      });
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
