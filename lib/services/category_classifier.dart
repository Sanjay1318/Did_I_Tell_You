import 'package:flutter/material.dart';

class CategoryClassifier {
  static const Map<String, List<String>> _categoryKeywords = {
    'money': [
      'lent',
      'borrowed',
      'owed',
      'owes',
      'paid',
      'payment',
      'bought',
      'purchase',
      'purchased',
      'expense',
      'spent',
      'cash',
      'money',
      '₹',
      'rs',
      'rupees',
      'price',
      'cost',
      'bill',
      'fee',
      'salary',
      'rent',
      'loan',
      'debt',
      'repay',
      'repayment',
      'invoice',
      'emi',
    ],
    'people': [
      'birthday',
      'anniversary',
      'likes',
      'loves',
      'prefers',
      'favorite',
      'favourite',
      'married',
      'engaged',
      'graduated',
      'moved',
      'lives',
      'recommended',
      'suggested',
      'met',
      'introduced',
      'friend',
      'family',
      'relationship',
      'personality',
      'preference',
    ],
    'events': [
      'meeting',
      'appointment',
      'interview',
      'deadline',
      'schedule',
      'scheduled',
      'planned',
      'event',
      'party',
      'function',
      'ceremony',
      'wedding',
      'conference',
      'seminar',
      'workshop',
      'presentation',
      'call',
      'zoom',
      'google meet',
      'teams meeting',
    ],
    'purchases': [
      'bought',
      'purchased',
      'ordered',
      'shipped',
      'delivered',
      'warranty',
      'guarantee',
      'receipt',
      'product',
      'item',
      'gadget',
      'device',
      'amazon',
      'flipkart',
      'myntra',
      'ajio',
      'meesho',
    ],
    'places': [
      'parked',
      'parking',
      'address',
      'location',
      'restaurant',
      'hotel',
      'cafe',
      'shop',
      'store',
      'mall',
      'airport',
      'station',
      'route',
      'direction',
      'landmark',
      'building',
      'floor',
      'gate',
      'near',
    ],
    'entertainment': [
      'watched',
      'movie',
      'film',
      'series',
      'show',
      'book',
      'novel',
      'read',
      'reading',
      'game',
      'played',
      'gaming',
      'music',
      'song',
      'concert',
      'theatre',
      'theater',
      'netflix',
      'prime',
      'hotstar',
      'interstellar',
      'anime',
      'manga',
    ],
    'work': [
      'manager',
      'boss',
      'colleague',
      'client',
      'project',
      'task',
      'assignment',
      'report',
      'presentation',
      'meeting',
      'deadline',
      'work',
      'office',
      'team',
      'salary',
      'promotion',
      'hr',
      'email',
      'standup',
      'sprint',
      'jira',
      'ticket',
    ],
    'education': [
      'study',
      'studied',
      'learn',
      'learned',
      'course',
      'class',
      'lecture',
      'exam',
      'test',
      'quiz',
      'assignment',
      'homework',
      'concept',
      'notes',
      'textbook',
      'chapter',
      'subject',
      'topic',
      'formula',
      'equation',
      'university',
      'college',
      'school',
      'degree',
      'semester',
    ],
    'important': [
      'password',
      'wifi',
      'account',
      'pin',
      'otp',
      'document',
      'license',
      'passport',
      'aadhar',
      'pan card',
      'insurance',
      'policy',
      'emergency',
      'contact',
      'number',
      'code',
      'key',
      'lock',
    ],
  };

  static String classify(String text) {
    final lower = text.toLowerCase();
    final scores = <String, int>{};

    for (final entry in _categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          scores[entry.key] = (scores[entry.key] ?? 0) + 1;
        }
      }
    }

    if (scores.isEmpty) return 'general';

    String bestCategory = 'general';
    int bestScore = 0;
    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestCategory = entry.key;
      }
    }

    return bestCategory;
  }

  static String getCategoryIcon(String category) {
    switch (category) {
      case 'money':
        return '💰';
      case 'people':
        return '👥';
      case 'events':
        return '📅';
      case 'purchases':
        return '🛍️';
      case 'places':
        return '📍';
      case 'entertainment':
        return '🎬';
      case 'work':
        return '💼';
      case 'education':
        return '🎓';
      case 'important':
        return '🔐';
      default:
        return '📝';
    }
  }

  static String getCategoryLabel(String category) {
    final labels = {
      'money': 'Money',
      'people': 'People',
      'events': 'Events',
      'purchases': 'Purchases',
      'places': 'Places',
      'entertainment': 'Entertainment',
      'work': 'Work',
      'education': 'Education',
      'important': 'Important',
      'general': 'General',
    };
    return labels[category] ?? 'General';
  }

  static Color? getCategoryColor(String category) {
    switch (category) {
      case 'money':
        return const Color(0xFF2E7D32);
      case 'people':
        return const Color(0xFF1565C0);
      case 'events':
        return const Color(0xFFE65100);
      case 'purchases':
        return const Color(0xFF6A1B9A);
      case 'places':
        return const Color(0xFF00838F);
      case 'entertainment':
        return const Color(0xFFAD1457);
      case 'work':
        return const Color(0xFF37474F);
      case 'education':
        return const Color(0xFF283593);
      case 'important':
        return const Color(0xFFB71C1C);
      default:
        return const Color(0xFF546E7A);
    }
  }

  static List<String> getAllCategories() {
    return [
      'general',
      'money',
      'people',
      'events',
      'purchases',
      'places',
      'entertainment',
      'work',
      'education',
      'important',
    ];
  }
}
