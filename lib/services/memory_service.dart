import 'package:flutter/foundation.dart';
import '../models/memory.dart';
import 'database_service.dart';
import 'entity_extractor.dart';
import 'category_classifier.dart';
import 'duplicate_detector.dart';
import 'reminder_service.dart';
import 'commitment_extractor.dart';
import 'attachment_service.dart';

class MemoryService extends ChangeNotifier {
  final DatabaseService _dbService;
  final ReminderService _reminders;
  List<Memory> _memories = [];
  bool _isLoading = false;
  String? _error;

  MemoryService(this._dbService, {ReminderService? reminders})
      : _reminders = reminders ?? ReminderService.instance;

  List<Memory> get memories => List.unmodifiable(_memories);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMemories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _memories = await _dbService.getAllMemories();
    } catch (e) {
      _error = 'Failed to load memories: $e';
      debugPrint('loadMemories error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Memory?> addMemory(
    String text, {
    DateTime? reminderAt,
    List<String> tags = const [],
    List<String> attachmentPaths = const [],
    String? recurrence,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      _error = 'A memory cannot be empty.';
      notifyListeners();
      return null;
    }
    try {
      _error = null;
      final person = EntityExtractor.extractPerson(normalizedText);
      final amount = EntityExtractor.extractAmount(normalizedText);
      final extractedDate = EntityExtractor.extractDate(normalizedText);
      final location = EntityExtractor.extractLocation(normalizedText);
      final category = CategoryClassifier.classify(normalizedText);
      final commitment = CommitmentExtractor.extract(normalizedText);

      final memory = Memory(
        originalText: normalizedText,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        category: category,
        person: person,
        amount: amount,
        extractedDate: extractedDate,
        location: location,
        reminderAt: reminderAt?.toIso8601String(),
        tags: tags
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList(),
        attachmentPaths: attachmentPaths,
        taskAction: commitment?.action,
        taskStatus: commitment?.status ?? 'none',
        recurrence: recurrence,
        metadata: {
          'keywords': EntityExtractor.extractKeywords(normalizedText).join(','),
        },
      );

      final id = await _dbService.insertMemory(memory);
      final newMemory = memory.copyWith(id: id);
      if (reminderAt != null && reminderAt.isAfter(DateTime.now())) {
        try {
          await _reminders.scheduleReminder(
            id: id,
            title: 'Memory reminder',
            body: normalizedText,
            scheduledTime: reminderAt,
          );
        } catch (e) {
          debugPrint('scheduleReminder error: $e');
        }
      }
      _memories.insert(0, newMemory);
      notifyListeners();
      return newMemory;
    } catch (e) {
      _error = 'Could not save memory. Please try again.';
      notifyListeners();
      debugPrint('addMemory error: $e');
      return null;
    }
  }

  Future<bool> updateMemory(Memory memory, {bool reanalyze = true}) async {
    try {
      _error = null;
      final text = memory.originalText.trim();
      if (text.isEmpty || memory.id == null) return false;
      final updated = Memory(
        id: memory.id,
        originalText: text,
        createdAt: memory.createdAt,
        updatedAt: DateTime.now(),
        person: reanalyze ? EntityExtractor.extractPerson(text) : memory.person,
        amount: reanalyze ? EntityExtractor.extractAmount(text) : memory.amount,
        extractedDate: reanalyze
            ? EntityExtractor.extractDate(text)
            : memory.extractedDate,
        location:
            reanalyze ? EntityExtractor.extractLocation(text) : memory.location,
        category:
            reanalyze ? CategoryClassifier.classify(text) : memory.category,
        status: memory.status,
        isPinned: memory.isPinned,
        reminderAt: memory.reminderAt,
        moneyStatus: memory.moneyStatus,
        tags: memory.tags,
        attachmentPaths: memory.attachmentPaths,
        taskAction: reanalyze
            ? CommitmentExtractor.extract(text)?.action
            : memory.taskAction,
        taskStatus: reanalyze
            ? CommitmentExtractor.extract(text)?.status ?? 'none'
            : memory.taskStatus,
        recurrence: memory.recurrence,
        metadata: reanalyze
            ? {'keywords': EntityExtractor.extractKeywords(text).join(',')}
            : memory.metadata,
      );
      await _dbService.updateMemory(updated);
      final index = _memories.indexWhere((m) => m.id == updated.id);
      if (index != -1) {
        _memories[index] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Could not update memory. Please try again.';
      notifyListeners();
      debugPrint('updateMemory error: $e');
      return false;
    }
  }

  Future<bool> deleteMemory(int id) async {
    try {
      final memory = _memories.where((memory) => memory.id == id).firstOrNull;
      await _dbService.deleteMemory(id);
      _memories.removeWhere((m) => m.id == id);
      if (memory != null) {
        await AttachmentService.deleteFiles(memory.attachmentPaths);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Could not delete memory. Please try again.';
      notifyListeners();
      debugPrint('deleteMemory error: $e');
      return false;
    }
  }

  Future<bool> deleteAllMemories() async {
    try {
      await _dbService.deleteAllMemories();
      _memories.clear();
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Could not delete memories. Please try again.';
      notifyListeners();
      debugPrint('deleteAllMemories error: $e');
      return false;
    }
  }

  Future<bool> setPinned(Memory memory, bool isPinned) =>
      _replaceMemory(memory.copyWith(isPinned: isPinned));

  Future<bool> archiveMemory(Memory memory) =>
      _replaceMemory(memory.copyWith(status: 'archived'));

  Future<bool> restoreMemory(Memory memory) =>
      _replaceMemory(memory.copyWith(status: 'active'));

  Future<bool> setMoneyStatus(Memory memory, String moneyStatus) =>
      _replaceMemory(memory.copyWith(moneyStatus: moneyStatus));

  Future<bool> setTaskStatus(Memory memory, String taskStatus) =>
      _replaceMemory(memory.copyWith(taskStatus: taskStatus));

  Future<bool> setReminder(Memory memory, DateTime? reminderAt) {
    final updated = Memory(
      id: memory.id,
      originalText: memory.originalText,
      createdAt: memory.createdAt,
      updatedAt: DateTime.now(),
      category: memory.category,
      person: memory.person,
      amount: memory.amount,
      extractedDate: memory.extractedDate,
      location: memory.location,
      status: memory.status,
      isPinned: memory.isPinned,
      reminderAt: reminderAt?.toIso8601String(),
      moneyStatus: memory.moneyStatus,
      tags: memory.tags,
      attachmentPaths: memory.attachmentPaths,
      taskAction: memory.taskAction,
      taskStatus: memory.taskStatus,
      recurrence: memory.recurrence,
      metadata: memory.metadata,
    );
    return _replaceMemory(updated).then((saved) async {
      if (!saved || memory.id == null) return saved;
      await _reminders.cancelReminder(memory.id!);
      if (reminderAt != null && reminderAt.isAfter(DateTime.now())) {
        await _reminders.scheduleReminder(
          id: memory.id!,
          title: 'Memory reminder',
          body: memory.originalText,
          scheduledTime: reminderAt,
        );
      }
      return saved;
    });
  }

  Future<bool> _replaceMemory(Memory updated) async {
    try {
      await _dbService.updateMemory(updated);
      final index = _memories.indexWhere((memory) => memory.id == updated.id);
      if (index != -1) {
        if (updated.status == 'archived') {
          _memories.removeAt(index);
        } else {
          _memories[index] = updated;
          _memories.sort((a, b) {
            final pinned = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
            return pinned != 0 ? pinned : b.createdAt.compareTo(a.createdAt);
          });
        }
      } else if (updated.status == 'active') {
        _memories.insert(0, updated);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Could not update memory. Please try again.';
      notifyListeners();
      debugPrint('replaceMemory error: $e');
      return false;
    }
  }

  Future<List<Memory>> getArchivedMemories() =>
      _dbService.getArchivedMemories();

  Future<int> importMemories(List<Memory> memories) async {
    var imported = 0;
    try {
      for (final memory in memories) {
        final exists = _memories.any((existing) =>
            existing.originalText.trim().toLowerCase() ==
                memory.originalText.trim().toLowerCase() &&
            existing.createdAt == memory.createdAt);
        if (exists) continue;
        final importedMemory = Memory(
          originalText: memory.originalText,
          createdAt: memory.createdAt,
          updatedAt: memory.updatedAt,
          category: memory.category,
          person: memory.person,
          amount: memory.amount,
          extractedDate: memory.extractedDate,
          location: memory.location,
          status: memory.status,
          isPinned: memory.isPinned,
          reminderAt: memory.reminderAt,
          moneyStatus: memory.moneyStatus,
          tags: memory.tags,
          attachmentPaths: memory.attachmentPaths,
          taskAction: memory.taskAction,
          taskStatus: memory.taskStatus,
          recurrence: memory.recurrence,
          metadata: memory.metadata,
        );
        final id = await _dbService.insertMemory(importedMemory);
        if (importedMemory.status == 'active') {
          _memories.add(importedMemory.copyWith(id: id));
        }
        imported++;
      }
      _memories.sort((a, b) {
        final pinned = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
        return pinned != 0 ? pinned : b.createdAt.compareTo(a.createdAt);
      });
      notifyListeners();
      return imported;
    } catch (e) {
      _error = 'Could not import the backup.';
      notifyListeners();
      debugPrint('importMemories error: $e');
      return 0;
    }
  }

  Future<List<Memory>> searchMemories(String query) async {
    return await _dbService.searchMemories(query);
  }

  List<String> getAllPersons() {
    final persons = <String>{};
    for (final memory in _memories) {
      if (memory.person != null && memory.person!.isNotEmpty) {
        persons.add(memory.person!);
      }
    }
    final sorted = persons.toList()..sort();
    return sorted;
  }

  List<PersonSummary> getPersonSummaries() {
    final map = <String, List<Memory>>{};
    for (final memory in _memories) {
      if (memory.person != null && memory.person!.isNotEmpty) {
        map.putIfAbsent(memory.person!, () => []).add(memory);
      }
    }
    final summaries = map.entries
        .map((e) => PersonSummary(
              name: e.key,
              memories: e.value,
              mentionCount: e.value.length,
            ))
        .toList()
      ..sort((a, b) => b.mentionCount.compareTo(a.mentionCount));
    return summaries;
  }

  List<Memory> getMemoriesForDate(DateTime date) {
    return _memories.where((m) {
      final created = m.createdAt;
      return created.year == date.year &&
          created.month == date.month &&
          created.day == date.day;
    }).toList();
  }

  Map<String, List<Memory>> groupMemoriesByDay() {
    final map = <String, List<Memory>>{};
    for (final memory in _memories) {
      final key = _formatDateKey(memory.createdAt);
      map.putIfAbsent(key, () => []).add(memory);
    }
    return map;
  }

  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final memoryDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(memoryDate).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    // Within a week either side of today a weekday name is clear enough;
    // further away it would be ambiguous, so show the full date.
    if (diff < 7 && diff > -7) {
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return days[date.weekday - 1];
    }
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<String?> checkDuplicate(String text) async {
    for (final memory in _memories) {
      if (DuplicateDetector.isDuplicate(text, memory.originalText)) {
        return 'You already told me something very similar.';
      }
      if (DuplicateDetector.isSimilar(text, memory.originalText)) {
        return 'This is similar to something you told me before.';
      }
      if (DuplicateDetector.mightContradict(text, memory.originalText)) {
        return 'It looks like this may update or contradict a previous memory.';
      }
    }
    return null;
  }

  List<Memory> parseNaturalQuery(String query) {
    final lower = query.toLowerCase().trim();

    if (lower.contains('who owes me') || lower.contains('who owe me')) {
      return _memories
          .where((m) =>
              m.category == 'money' &&
              (m.originalText.toLowerCase().contains('lent') ||
                  m.originalText.toLowerCase().contains('borrowed') ||
                  m.originalText.toLowerCase().contains('owes')))
          .toList();
    }

    if (lower.contains('what do i know about') ||
        lower.contains('show everything related to') ||
        lower.contains('tell me about')) {
      final personMatch = RegExp(r'(?:about|related to|to me about)\s+(\w+)',
              caseSensitive: false)
          .firstMatch(lower);
      if (personMatch != null) {
        final person = personMatch.group(1)!.toLowerCase();
        return _memories
            .where((m) =>
                m.person?.toLowerCase() == person ||
                m.originalText.toLowerCase().contains(person))
            .toList();
      }
    }

    for (final memory in _memories) {
      if (memory.person != null &&
          lower.contains(memory.person!.toLowerCase())) {
        return _memories
            .where(
                (m) => m.person?.toLowerCase() == memory.person!.toLowerCase())
            .toList();
      }
    }

    if (lower.contains('yesterday')) {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      return getMemoriesForDate(yesterday);
    }

    if (lower.contains('last week')) {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      return _memories
          .where((m) =>
              m.createdAt.isAfter(weekAgo) &&
              m.createdAt.isBefore(DateTime.now()))
          .toList();
    }

    if (lower.contains('today')) {
      return getMemoriesForDate(DateTime.now());
    }

    for (final category in CategoryClassifier.getAllCategories()) {
      final label = CategoryClassifier.getCategoryLabel(category).toLowerCase();
      if (lower.contains(label)) {
        return _memories.where((m) => m.category == category).toList();
      }
    }

    return _memories
        .where((m) =>
            m.originalText.toLowerCase().contains(lower) ||
            m.tags.any((tag) => tag.toLowerCase().contains(lower)))
        .toList();
  }

  Map<String, List<Memory>> getUpcomingReminders() {
    final upcoming = <String, List<Memory>>{};
    for (final memory in _memories) {
      if (memory.extractedDate != null) {
        final date = DateTime.tryParse(memory.extractedDate!);
        if (date != null && date.isAfter(DateTime.now())) {
          final key = _formatDateKey(date);
          upcoming.putIfAbsent(key, () => []).add(memory);
        }
      }
    }
    return upcoming;
  }
}
