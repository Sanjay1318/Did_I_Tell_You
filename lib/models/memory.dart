import 'dart:convert';

class Memory {
  final int? id;
  final String originalText;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String category;
  final String? person;
  final double? amount;
  final String? extractedDate;
  final String? location;
  final String status;
  final bool isPinned;
  final String? reminderAt;
  final String moneyStatus;
  final List<String> tags;
  final List<String> attachmentPaths;
  final String? taskAction;
  final String taskStatus;
  final String? recurrence;
  final Map<String, dynamic> metadata;

  Memory({
    this.id,
    required this.originalText,
    required this.createdAt,
    required this.updatedAt,
    required this.category,
    this.person,
    this.amount,
    this.extractedDate,
    this.location,
    this.status = 'active',
    this.isPinned = false,
    this.reminderAt,
    this.moneyStatus = 'open',
    this.tags = const [],
    this.attachmentPaths = const [],
    this.taskAction,
    this.taskStatus = 'none',
    this.recurrence,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'original_text': originalText,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'category': category,
      'person': person,
      'amount': amount,
      'extracted_date': extractedDate,
      'location': location,
      'status': status,
      'is_pinned': isPinned ? 1 : 0,
      'reminder_at': reminderAt,
      'money_status': moneyStatus,
      'tags': jsonEncode(tags),
      'attachment_paths': jsonEncode(attachmentPaths),
      'task_action': taskAction,
      'task_status': taskStatus,
      'recurrence': recurrence,
      'metadata': metadata.isEmpty ? '{}' : _encodeMetadata(metadata),
    };
  }

  factory Memory.fromMap(Map<String, dynamic> map) {
    return Memory(
      id: map['id'] as int?,
      originalText: map['original_text'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      category: map['category'] as String? ?? 'general',
      person: map['person'] as String?,
      amount: (map['amount'] as num?)?.toDouble(),
      extractedDate: map['extracted_date'] as String?,
      location: map['location'] as String?,
      status: map['status'] as String? ?? 'active',
      isPinned: (map['is_pinned'] as num? ?? 0) == 1,
      reminderAt: map['reminder_at'] as String?,
      moneyStatus: map['money_status'] as String? ?? 'open',
      tags: _decodeStringList(map['tags'] as String?),
      attachmentPaths: _decodeStringList(map['attachment_paths'] as String?),
      taskAction: map['task_action'] as String?,
      taskStatus: map['task_status'] as String? ?? 'none',
      recurrence: map['recurrence'] as String?,
      metadata: _decodeMetadata(map['metadata'] as String?),
    );
  }

  static String _encodeMetadata(Map<String, dynamic> data) {
    return jsonEncode(data);
  }

  static Map<String, dynamic> _decodeMetadata(String? raw) {
    if (raw == null || raw.isEmpty || raw == '{}') return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      // Migrate metadata written by versions before JSON encoding was used.
    }
    final map = <String, dynamic>{};
    for (final part in raw.split('|')) {
      if (part.contains(':')) {
        final idx = part.indexOf(':');
        map[part.substring(0, idx)] = part.substring(idx + 1);
      }
    }
    return map;
  }

  static List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toList();
    } on FormatException {
      // Legacy databases did not store lists in these fields.
    }
    return const [];
  }

  Memory copyWith({
    int? id,
    String? originalText,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? category,
    String? person,
    double? amount,
    String? extractedDate,
    String? location,
    String? status,
    bool? isPinned,
    String? reminderAt,
    String? moneyStatus,
    List<String>? tags,
    List<String>? attachmentPaths,
    String? taskAction,
    String? taskStatus,
    String? recurrence,
    bool clearRecurrence = false,
    Map<String, dynamic>? metadata,
  }) {
    return Memory(
      id: id ?? this.id,
      originalText: originalText ?? this.originalText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
      person: person ?? this.person,
      amount: amount ?? this.amount,
      extractedDate: extractedDate ?? this.extractedDate,
      location: location ?? this.location,
      status: status ?? this.status,
      isPinned: isPinned ?? this.isPinned,
      reminderAt: reminderAt ?? this.reminderAt,
      moneyStatus: moneyStatus ?? this.moneyStatus,
      tags: tags ?? this.tags,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      taskAction: taskAction ?? this.taskAction,
      taskStatus: taskStatus ?? this.taskStatus,
      recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
      metadata: metadata ?? this.metadata,
    );
  }
}

class PersonSummary {
  final String name;
  final List<Memory> memories;
  final int mentionCount;

  PersonSummary({
    required this.name,
    required this.memories,
    required this.mentionCount,
  });
}
