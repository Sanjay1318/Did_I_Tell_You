class EntityExtractor {
  static const Set<String> _commonIndianNames = {
    'rahul',
    'priya',
    'amit',
    'sneha',
    'vikram',
    'ananya',
    'arjun',
    'kavya',
    'rohan',
    'divya',
    'karan',
    'neha',
    'sanjay',
    'pooja',
    'rajesh',
    'meera',
    'aditya',
    'shreya',
    'nikhil',
    'anita',
    'suresh',
    'lakshmi',
    'deepak',
    'riya',
    'manish',
    'kriti',
    'gaurav',
    'ishita',
    'vivek',
    'tanvi',
    'akash',
    'nisha',
    'harsh',
    'simran',
    'abhishek',
    'anushka',
    'siddharth',
    'swati',
    'varun',
    'priyanka',
    'sameer',
    'aishwarya',
    'kunal',
    'bhavna',
    'prashant',
    'rekha',
    'ashok',
    'maya',
    'dinesh',
    'sunita',
    'prakash',
    'geeta',
    'ramesh',
    'kiran',
    'sachin',
    'sangeeta',
    'manoj',
    'renuka',
    'ajay',
    'chitra',
    'ravi',
    'deepika',
    'mohan',
    'jaya',
    'harish',
    'anjali',
    'naveen',
    'komal',
    'pankaj',
    'rashmi',
    'alok',
    'shalini',
  };

  static const Set<String> _dateKeywords = {
    'today',
    'tomorrow',
    'yesterday',
    'tonight',
  };

  static const Set<String> _daysOfWeek = {
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  };

  static const Set<String> _months = {
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
    'jan',
    'feb',
    'mar',
    'apr',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  };

  static final RegExp _amountRegex = RegExp(
    r'(?:₹|rs\.?|inr)\s*(\d+(?:,\d+)*(?:\.\d+)?)',
    caseSensitive: false,
  );

  static final RegExp _plainAmountRegex = RegExp(
    r'(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:rupees|rs\b)',
    caseSensitive: false,
  );

  static final RegExp _locationRegex = RegExp(
    r'\b(?:at|in|near|parked at|parked in)\s+([A-Z][a-zA-Z]*(?:\s+[A-Z][a-zA-Z]*)*)',
  );

  static String? extractPerson(String text) {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    for (int i = 0; i < words.length; i++) {
      final word = words[i].replaceAll(RegExp(r'[.,!?;:]'), '');
      if (_commonIndianNames.contains(word)) {
        return word[0].toUpperCase() + word.substring(1);
      }
    }
    for (int i = 0; i < words.length; i++) {
      final word = words[i].replaceAll(RegExp(r'[.,!?;:]'), '');
      if (word.length > 2 &&
          word[0] == word[0].toUpperCase() &&
          word[0] != word[0].toLowerCase() &&
          !word.contains(RegExp(r'[0-9]'))) {
        final lower = word.toLowerCase();
        if (!_dateKeywords.contains(lower) &&
            !_daysOfWeek.contains(lower) &&
            !_months.contains(lower) &&
            !['i', 'the', 'my', 'he', 'she', 'we'].contains(lower)) {
          return word;
        }
      }
    }
    return null;
  }

  static double? extractAmount(String text) {
    final match = _amountRegex.firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', ''));
    }
    final plainMatch = _plainAmountRegex.firstMatch(text);
    if (plainMatch != null) {
      return double.tryParse(plainMatch.group(1)!.replaceAll(',', ''));
    }
    return null;
  }

  static String? extractDate(String text) {
    final lower = text.toLowerCase();
    final now = DateTime.now();

    for (final day in _daysOfWeek) {
      if (lower.contains('last $day')) {
        final currentDay = now.weekday;
        final targetDay = _dayToInt(day);
        int diff = currentDay - targetDay;
        if (diff <= 0) diff += 7;
        diff += 7;
        return now.subtract(Duration(days: diff)).toIso8601String();
      }
      if (lower.contains('this $day') || lower.contains('on $day')) {
        final currentDay = now.weekday;
        final targetDay = _dayToInt(day);
        int diff = targetDay - currentDay;
        if (diff < 0) diff += 7;
        return now.add(Duration(days: diff)).toIso8601String();
      }
    }

    if (lower.contains('tomorrow')) {
      return now.add(const Duration(days: 1)).toIso8601String();
    }
    if (lower.contains('yesterday')) {
      return now.subtract(const Duration(days: 1)).toIso8601String();
    }
    if (lower.contains('today') || lower.contains('tonight')) {
      return now.toIso8601String();
    }

    for (final month in _months) {
      final pattern = RegExp(
        '\\b$month\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(text);
      if (match != null) {
        final monthNum = _monthToInt(month);
        final day = int.tryParse(match.group(1)!);
        if (monthNum != null && day != null && day >= 1 && day <= 31) {
          var year = now.year;
          var date = DateTime(year, monthNum, day);
          if (date.isBefore(now.subtract(const Duration(days: 30)))) {
            date = DateTime(year + 1, monthNum, day);
          }
          return date.toIso8601String();
        }
      }
    }

    final datePattern = RegExp(
      r'(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?',
    );
    final dateMatch = datePattern.firstMatch(text);
    if (dateMatch != null) {
      final day = int.tryParse(dateMatch.group(1)!);
      final month = int.tryParse(dateMatch.group(2)!);
      final yearStr = dateMatch.group(3);
      if (day != null && month != null && day <= 31 && month <= 12) {
        var year = now.year;
        if (yearStr != null) {
          year = yearStr.length == 2
              ? 2000 + int.parse(yearStr)
              : int.parse(yearStr);
        }
        final date = DateTime(year, month, day);
        if (date.isBefore(now.subtract(const Duration(days: 365)))) {
          return DateTime(year + 1, month, day).toIso8601String();
        }
        return date.toIso8601String();
      }
    }

    return null;
  }

  static String? extractLocation(String text) {
    final match = _locationRegex.firstMatch(text);
    if (match != null) {
      return match.group(1)?.trim();
    }
    return null;
  }

  static List<String> extractKeywords(String text) {
    final stopWords = {
      'the',
      'a',
      'an',
      'is',
      'are',
      'was',
      'were',
      'i',
      'me',
      'my',
      'mine',
      'you',
      'your',
      'he',
      'she',
      'it',
      'we',
      'they',
      'him',
      'her',
      'them',
      'to',
      'for',
      'of',
      'in',
      'on',
      'at',
      'with',
      'about',
      'this',
      'that',
      'and',
      'or',
      'but',
      'from',
      'by',
      'so',
      'very',
      'just',
      'have',
      'has',
      'had',
      'will',
      'would',
      'should',
      'could',
      'can',
      'may',
      'might',
      'been',
      'being',
      'am',
      'do',
      'does',
      'did',
      'done',
      'get',
      'got',
      'go',
      'went',
      'what',
      'when',
      'where',
      'who',
      'whom',
      'which',
      'how',
      'why',
      'if',
      'then',
      'than',
      'as',
      'be',
      'not',
      'no',
      'yes',
    };

    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final keywords = <String>[];
    for (final word in words) {
      final clean = word.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (clean.length > 3 && !stopWords.contains(clean)) {
        keywords.add(clean);
      }
    }
    return keywords;
  }

  static int _dayToInt(String day) {
    const days = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };
    return days[day] ?? 1;
  }

  static int? _monthToInt(String month) {
    const months = {
      'january': 1,
      'jan': 1,
      'february': 2,
      'feb': 2,
      'march': 3,
      'mar': 3,
      'april': 4,
      'apr': 4,
      'may': 5,
      'june': 6,
      'jun': 6,
      'july': 7,
      'jul': 7,
      'august': 8,
      'aug': 8,
      'september': 9,
      'sep': 9,
      'october': 10,
      'oct': 10,
      'november': 11,
      'nov': 11,
      'december': 12,
      'dec': 12,
    };
    return months[month.toLowerCase()];
  }
}
