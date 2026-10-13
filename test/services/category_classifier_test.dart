import 'package:did_i_tell_you/services/category_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategoryClassifier.classify', () {
    test('money', () {
      expect(CategoryClassifier.classify('I lent Rahul 500 rupees yesterday'),
          'money');
    });

    test('places', () {
      expect(CategoryClassifier.classify('Parked at Forum Mall, level 2'),
          'places');
    });

    test('work', () {
      expect(
        CategoryClassifier.classify(
            'Team standup with client about the sprint report tomorrow'),
        'work',
      );
    });

    test('important', () {
      expect(CategoryClassifier.classify('My wifi password is abc123'),
          'important');
    });

    test('entertainment', () {
      expect(CategoryClassifier.classify('Watched Interstellar on Netflix'),
          'entertainment');
    });

    test('purchases', () {
      expect(CategoryClassifier.classify('Bought a new phone from Amazon'),
          'purchases');
    });

    test('is case-insensitive', () {
      expect(CategoryClassifier.classify('MY WIFI PASSWORD IS ABC123'),
          'important');
    });

    test('falls back to general when nothing matches', () {
      expect(CategoryClassifier.classify('Hello there'), 'general');
    });

    test('returns general for an empty string', () {
      expect(CategoryClassifier.classify(''), 'general');
    });

    test('always returns a known category', () {
      const samples = [
        'I lent Rahul 500 rupees yesterday',
        'Parked at Forum Mall',
        'Hello there',
        '',
        '₹ 100 !!!',
      ];
      for (final text in samples) {
        expect(CategoryClassifier.getAllCategories(),
            contains(CategoryClassifier.classify(text)),
            reason: 'for "$text"');
      }
    });

    test('does not match keywords inside other words', () {
      expect(CategoryClassifier.classify('Three apples'), 'general');
    });

    test('plural and -ed/-ing forms of a keyword still match', () {
      expect(CategoryClassifier.classify('Meetings with the clients'), 'work');
      expect(CategoryClassifier.classify('Studying for exams'), 'education');
    });

    test('the rupee symbol next to digits counts as money', () {
      expect(CategoryClassifier.classify('Got ₹500'), 'money');
    });

    test('punctuation does not hide a keyword', () {
      expect(CategoryClassifier.classify('Wifi, password: abc123!'),
          'important');
    });
  });

  group('CategoryClassifier helpers', () {
    test('getAllCategories lists general first and has no duplicates', () {
      final all = CategoryClassifier.getAllCategories();
      expect(all.first, 'general');
      expect(all.toSet().length, all.length);
      expect(all.length, 10);
    });

    test('every category has a label, and only general uses the fallback', () {
      for (final category in CategoryClassifier.getAllCategories()) {
        final label = CategoryClassifier.getCategoryLabel(category);
        expect(label, isNotEmpty);
        if (category != 'general') {
          expect(label, isNot('General'), reason: category);
        }
      }
    });

    test('unknown categories fall back to General', () {
      expect(CategoryClassifier.getCategoryLabel('nonsense'), 'General');
    });

    test('labels match the display names', () {
      expect(CategoryClassifier.getCategoryLabel('money'), 'Money');
      expect(CategoryClassifier.getCategoryLabel('entertainment'),
          'Entertainment');
    });

    test('every category has an icon and a color', () {
      for (final category in CategoryClassifier.getAllCategories()) {
        expect(CategoryClassifier.getCategoryIcon(category), isNotEmpty);
        expect(CategoryClassifier.getCategoryColor(category), isNotNull);
      }
    });

    test('unknown categories use the default icon', () {
      expect(CategoryClassifier.getCategoryIcon('nonsense'),
          CategoryClassifier.getCategoryIcon('general'));
    });
  });
}
