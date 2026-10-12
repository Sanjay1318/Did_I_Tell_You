import 'package:flutter_test/flutter_test.dart';
import 'package:did_i_tell_you/models/memory.dart';
import 'package:did_i_tell_you/services/category_classifier.dart';
import 'package:did_i_tell_you/services/duplicate_detector.dart';
import 'package:did_i_tell_you/services/entity_extractor.dart';

void main() {
  group('Memory serialization', () {
    test('preserves structured metadata and normalizes numeric database values',
        () {
      final memory = Memory(
        id: 7,
        originalText: 'I lent Rahul 500 rupees',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        category: 'money',
        amount: 500,
        isPinned: true,
        reminderAt: DateTime.utc(2026, 2, 1).toIso8601String(),
        moneyStatus: 'settled',
        tags: const ['Career', 'Ravi'],
        attachmentPaths: const ['/private/attachment.jpg'],
        taskAction: 'send my resume',
        taskStatus: 'pending',
        metadata: {'keywords': 'lent,rahul', 'source': 'voice'},
      );

      final restored = Memory.fromMap(memory.toMap());

      expect(restored.amount, 500.0);
      expect(restored.metadata, memory.metadata);
      expect(restored.isPinned, isTrue);
      expect(restored.reminderAt, memory.reminderAt);
      expect(restored.moneyStatus, 'settled');
      expect(restored.tags, ['Career', 'Ravi']);
      expect(restored.taskStatus, 'pending');
    });
  });

  group('Memory intelligence', () {
    test('detects money, people, and duplicate content', () {
      const text = 'I lent Rahul 500 rupees yesterday';

      expect(EntityExtractor.extractPerson(text), 'Rahul');
      expect(EntityExtractor.extractAmount(text), 500.0);
      expect(CategoryClassifier.classify(text), 'money');
      expect(DuplicateDetector.isDuplicate(text, text), isTrue);
    });
  });
}
