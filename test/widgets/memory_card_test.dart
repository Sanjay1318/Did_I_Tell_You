import 'package:did_i_tell_you/widgets/memory_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../database/db_test_support.dart' show makeMemory;

Future<void> pumpCard(
  WidgetTester tester,
  MemoryCard card,
) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));
}

void main() {
  testWidgets('shows the memory text', (tester) async {
    await pumpCard(
      tester,
      MemoryCard(memory: makeMemory(text: 'Parked at Forum Mall'), onTap: () {}),
    );
    expect(find.text('Parked at Forum Mall'), findsOneWidget);
  });

  testWidgets('shows the person and the amount when there are some',
      (tester) async {
    await pumpCard(
      tester,
      MemoryCard(
        memory: makeMemory(person: 'Rahul', amount: 500, category: 'money'),
        onTap: () {},
      ),
    );
    expect(find.text('👤 Rahul'), findsOneWidget);
    expect(find.text('💰 ₹500.0'), findsOneWidget);
  });

  testWidgets('shows no person or amount chip when they are missing',
      (tester) async {
    await pumpCard(
      tester,
      MemoryCard(memory: makeMemory(), onTap: () {}),
    );
    expect(find.textContaining('👤'), findsNothing);
    expect(find.textContaining('₹'), findsNothing);
  });

  testWidgets('an empty person name shows no chip', (tester) async {
    await pumpCard(
      tester,
      MemoryCard(memory: makeMemory(person: ''), onTap: () {}),
    );
    expect(find.textContaining('👤'), findsNothing);
  });

  testWidgets('shows the category icon', (tester) async {
    await pumpCard(
      tester,
      MemoryCard(memory: makeMemory(category: 'places'), onTap: () {}),
    );
    expect(find.text('📍'), findsOneWidget);
  });

  testWidgets('an unknown category falls back to the general icon',
      (tester) async {
    await pumpCard(
      tester,
      MemoryCard(memory: makeMemory(category: 'something-new'), onTap: () {}),
    );
    expect(find.text('📝'), findsOneWidget);
  });

  testWidgets('does not overflow on a narrow screen with every chip showing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 230,
            child: MemoryCard(
              memory: makeMemory(
                text: 'I lent Rahul 500 rupees',
                person: 'Rahul Venkata',
                amount: 12500,
                category: 'money',
                createdAt: DateTime.now(),
              ),
              onTap: () {},
            ),
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('👤 Rahul Venkata'), findsOneWidget);
    expect(find.text('💰 ₹12500.0'), findsOneWidget);
    expect(find.text('Just now'), findsOneWidget);
  });

  testWidgets('calls onTap when pressed', (tester) async {
    var taps = 0;
    await pumpCard(
      tester,
      MemoryCard(memory: makeMemory(text: 'tap me'), onTap: () => taps++),
    );
    await tester.tap(find.text('tap me'));
    expect(taps, 1);
  });

  testWidgets('cuts long text off after three lines', (tester) async {
    final long = List.filled(80, 'word').join(' ');
    await pumpCard(
      tester,
      MemoryCard(memory: makeMemory(text: long), onTap: () {}),
    );
    final text = tester.widget<Text>(find.text(long));
    expect(text.maxLines, 3);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  group('how long ago', () {
    final cases = <String, Duration>{
      'Just now': const Duration(seconds: 10),
      '5m ago': const Duration(minutes: 5, seconds: 10),
      '3h ago': const Duration(hours: 3, minutes: 1),
      'Yesterday': const Duration(hours: 25),
      '3d ago': const Duration(days: 3, hours: 1),
      '1w ago': const Duration(days: 8),
      '2w ago': const Duration(days: 15),
      '2mo ago': const Duration(days: 65),
      '2y ago': const Duration(days: 800),
    };

    cases.forEach((label, age) {
      testWidgets('$age ago reads "$label"', (tester) async {
        await pumpCard(
          tester,
          MemoryCard(
            memory: makeMemory(createdAt: DateTime.now().subtract(age)),
            onTap: () {},
          ),
        );
        expect(find.text(label), findsOneWidget);
      });
    });
  });
}
