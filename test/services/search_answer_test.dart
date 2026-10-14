import 'package:did_i_tell_you/services/search_answer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../database/db_test_support.dart' show makeMemory;

void main() {
  group('SearchAnswer.generate', () {
    test('gives no answer when nothing was found', () {
      expect(SearchAnswer.generate('who owes me', []), '');
    });

    group('"who owes me"', () {
      test('lists each person with the amount, rounded to whole rupees', () {
        final answer = SearchAnswer.generate('Who owes me money?', [
          makeMemory(person: 'Rahul', amount: 500),
          makeMemory(person: 'Priya', amount: 250.4),
          makeMemory(person: 'Amit', amount: 1500),
        ]);
        expect(answer,
            'Rahul owes you ₹500\nPriya owes you ₹250\nAmit owes you ₹1500');
      });

      test('says "Someone" when no person was detected', () {
        expect(
          SearchAnswer.generate('who owes me', [makeMemory(amount: 300)]),
          'Someone owes you ₹300',
        );
      });

      test('shows the original text when there is no amount', () {
        expect(
          SearchAnswer.generate('who owes me', [
            makeMemory(text: 'Rahul borrowed my charger', person: 'Rahul'),
          ]),
          'Rahul borrowed my charger',
        );
      });

      test('accepts "who owe me" in any letter case', () {
        expect(
          SearchAnswer.generate(
              '  WHO OWE ME  ', [makeMemory(person: 'Rahul', amount: 5)]),
          'Rahul owes you ₹5',
        );
      });
    });

    group('questions about a person', () {
      test('"what do I know about" counts the memories', () {
        final answer = SearchAnswer.generate('What do I know about Rahul?', [
          makeMemory(person: 'Rahul'),
          makeMemory(person: 'Rahul'),
        ]);
        expect(answer, 'You have 2 memories about Rahul.');
      });

      test('"tell me about" works the same way', () {
        expect(
          SearchAnswer.generate('tell me about priya', [
            makeMemory(person: 'Priya'),
            makeMemory(person: 'Priya'),
            makeMemory(person: 'Priya'),
          ]),
          'You have 3 memories about Priya.',
        );
      });

      test('uses singular for one memory', () {
        expect(
          SearchAnswer.generate(
              'tell me about Priya', [makeMemory(person: 'Priya')]),
          'You have 1 memory about Priya.',
        );
      });

      test('says "this person" when the first result has no person', () {
        expect(
          SearchAnswer.generate(
              'what do i know about meena', [makeMemory(text: 'Dinner')]),
          'You have 1 memory about this person.',
        );
      });
    });

    group('"where did I park"', () {
      test('quotes the first memory that mentions parking', () {
        final answer = SearchAnswer.generate('Where did I park?', [
          makeMemory(text: 'Bought milk'),
          makeMemory(text: 'Parked at Forum Mall, level 2'),
          makeMemory(text: 'Parked at the office'),
        ]);
        expect(answer, 'You parked: Parked at Forum Mall, level 2');
      });

      test('falls back to a count when no result mentions parking', () {
        expect(
          SearchAnswer.generate(
              'where did i park', [makeMemory(text: 'Bought milk')]),
          'Found 1 memory.',
        );
      });
    });

    group('preferences ("what does ... like")', () {
      for (final word in ['like', 'love', 'prefer', 'favorite']) {
        test('finds a memory containing "$word"', () {
          final text = 'Rahul will $word spicy food';
          expect(
            SearchAnswer.generate('what does Rahul eat', [
              makeMemory(text: 'Met Rahul'),
              makeMemory(text: text),
            ]),
            text,
          );
        });
      }

      test('"what food does" is recognised too', () {
        expect(
          SearchAnswer.generate('What food does Priya love?',
              [makeMemory(text: 'Priya loves dosa')]),
          'Priya loves dosa',
        );
      });

      test('falls back to a count when nothing says what they like', () {
        expect(
          SearchAnswer.generate('what does Rahul do', [
            makeMemory(text: 'Met Rahul'),
            makeMemory(text: 'Called Rahul'),
          ]),
          'Found 2 memories.',
        );
      });
    });

    test('any other question just counts the results', () {
      expect(
        SearchAnswer.generate('forum', [makeMemory(), makeMemory(), makeMemory()]),
        'Found 3 memories.',
      );
      expect(SearchAnswer.generate('forum', [makeMemory()]), 'Found 1 memory.');
    });

    test('an empty query still counts the results', () {
      expect(SearchAnswer.generate('', [makeMemory(), makeMemory()]),
          'Found 2 memories.');
    });

    test('"who owes me" wins when the question also says "tell me about"', () {
      expect(
        SearchAnswer.generate('tell me about who owes me',
            [makeMemory(person: 'Rahul', amount: 5)]),
        'Rahul owes you ₹5',
      );
    });
  });
}
