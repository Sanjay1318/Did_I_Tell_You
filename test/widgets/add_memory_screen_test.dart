import 'package:did_i_tell_you/screens/add_memory_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../database/db_test_support.dart' show makeMemory;
import '../helpers/fakes.dart';
import '../helpers/pump.dart';

// The microphone, camera/gallery and the date/time pickers need a real device,
// so they are not driven here.
void main() {
  Finder mainField() => find.byType(TextField).first;

  testWidgets('starts empty with the Save button switched off', (tester) async {
    final t = await makeService();
    await openScreen(tester, const AddMemoryScreen(), memories: t.service);

    expect(find.text('New Memory'), findsOneWidget);
    expect(find.text('🧠 What do you want me to remember?'), findsOneWidget);
    expect(buttonWithLabel(tester, 'Save Memory').onPressed, isNull);
    expect(find.text('🔍 I understood:'), findsNothing);
  });

  testWidgets('typing text switches the Save button on', (tester) async {
    final t = await makeService();
    await openScreen(tester, const AddMemoryScreen(), memories: t.service);

    await tester.enterText(mainField(), 'Parked at Forum Mall');
    await tester.pump();

    expect(buttonWithLabel(tester, 'Save Memory').onPressed, isNotNull);
  });

  testWidgets('blank text keeps Save switched off', (tester) async {
    final t = await makeService();
    await openScreen(tester, const AddMemoryScreen(), memories: t.service);

    await tester.enterText(mainField(), '    ');
    await tester.pump();

    expect(buttonWithLabel(tester, 'Save Memory').onPressed, isNull);
  });

  testWidgets('shows what it understood from the text', (tester) async {
    final t = await makeService();
    await openScreen(tester, const AddMemoryScreen(), memories: t.service);

    await tester.enterText(mainField(), 'I lent Rahul 500 rupees');
    await tester.pump();

    expect(find.text('🔍 I understood:'), findsOneWidget);
    expect(find.text('Rahul'), findsOneWidget);
    expect(find.text('₹500.0'), findsOneWidget);
    expect(find.text('💰 Money'), findsOneWidget);
  });

  testWidgets('shows nothing extra when nothing was recognised',
      (tester) async {
    final t = await makeService();
    await openScreen(tester, const AddMemoryScreen(), memories: t.service);

    await tester.enterText(mainField(), 'just a plain thought here');
    await tester.pump();

    expect(find.text('🔍 I understood:'), findsNothing);
  });

  testWidgets('saving adds the memory, closes the screen and says so',
      (tester) async {
    final t = await makeService();
    await openScreen(tester, const AddMemoryScreen(), memories: t.service);

    await tester.enterText(mainField(), 'I lent Rahul 500 rupees');
    await tester.pump();
    await tester.tap(find.text('Save Memory'));
    await tester.pumpAndSettle();

    expect(t.service.memories, hasLength(1));
    expect(t.service.memories.single.originalText, 'I lent Rahul 500 rupees');
    expect(t.service.memories.single.person, 'Rahul');
    expect(t.db.rows, hasLength(1));
    expect(find.byType(AddMemoryScreen), findsNothing);
    expect(find.text('🧠 Memory saved!'), findsOneWidget);
  });

  testWidgets('a failed save keeps the screen open and shows an error',
      (tester) async {
    final t = await makeService();
    t.db.failWrites = true;
    await openScreen(tester, const AddMemoryScreen(), memories: t.service);

    await tester.enterText(mainField(), 'This will not save');
    await tester.pump();
    await tester.tap(find.text('Save Memory'));
    await tester.pumpAndSettle();

    expect(find.byType(AddMemoryScreen), findsOneWidget);
    expect(find.text('Could not save memory. Please try again.'),
        findsOneWidget);
    expect(t.service.memories, isEmpty);
    // The text is still there and the button works again.
    expect(find.text('This will not save'), findsOneWidget);
    expect(buttonWithLabel(tester, 'Save Memory').onPressed, isNotNull);
  });

  group('options', () {
    testWidgets('are hidden until asked for', (tester) async {
      final t = await makeService();
      await openScreen(tester, const AddMemoryScreen(), memories: t.service);

      expect(find.text('Add tags, photo, or reminder'), findsOneWidget);
      expect(find.text('Tags'), findsNothing);
      expect(find.text('Add a reminder'), findsNothing);
      expect(find.text('Add photo or screenshot'), findsNothing);
    });

    testWidgets('can be shown and hidden again', (tester) async {
      final t = await makeService();
      await openScreen(tester, const AddMemoryScreen(), memories: t.service);

      await tester.tap(find.text('Add tags, photo, or reminder'));
      await tester.pump();
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Add a reminder'), findsOneWidget);
      expect(find.text('Add photo or screenshot'), findsOneWidget);
      expect(find.text('Remove reminder'), findsNothing);

      await tester.tap(find.text('Hide options'));
      await tester.pump();
      expect(find.text('Tags'), findsNothing);
    });

    testWidgets('tags typed in are saved cleaned up', (tester) async {
      final t = await makeService();
      await openScreen(tester, const AddMemoryScreen(), memories: t.service);

      await tester.enterText(mainField(), 'Interview with Ravi on Friday');
      await tester.tap(find.text('Add tags, photo, or reminder'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), 'Work, , Career ,Work');
      await tester.tap(find.text('Save Memory'));
      await tester.pumpAndSettle();

      expect(t.service.memories.single.tags, ['Work', 'Career']);
    });

    testWidgets('a memory saved without options has no tags or reminder',
        (tester) async {
      final t = await makeService();
      await openScreen(tester, const AddMemoryScreen(), memories: t.service);

      await tester.enterText(mainField(), 'Plain note');
      await tester.pump();
      await tester.tap(find.text('Save Memory'));
      await tester.pumpAndSettle();

      expect(t.service.memories.single.tags, isEmpty);
      expect(t.service.memories.single.reminderAt, isNull);
      expect(t.reminders.scheduled, isEmpty);
    });
  });

  group('duplicate warning', () {
    final existing = makeMemory(text: 'I lent Rahul 500 rupees');

    testWidgets('appears for text like one already saved', (tester) async {
      final t = await makeService([existing]);
      await openScreen(tester, const AddMemoryScreen(), memories: t.service);

      await tester.enterText(mainField(), 'I lent Rahul 500 rupees');
      await tester.pumpAndSettle();

      expect(find.text('You already told me something very similar.'),
          findsOneWidget);
    });

    testWidgets('does not appear for very short text', (tester) async {
      final t = await makeService([makeMemory(text: 'I lent')]);
      await openScreen(tester, const AddMemoryScreen(), memories: t.service);

      await tester.enterText(mainField(), 'I lent');
      await tester.pumpAndSettle();

      expect(find.textContaining('similar'), findsNothing);
    });

    testWidgets('goes away when the text changes to something different',
        (tester) async {
      final t = await makeService([existing]);
      await openScreen(tester, const AddMemoryScreen(), memories: t.service);

      await tester.enterText(mainField(), 'I lent Rahul 500 rupees');
      await tester.pumpAndSettle();
      expect(find.textContaining('already told me'), findsOneWidget);

      await tester.enterText(mainField(), 'Bought milk and bread');
      await tester.pumpAndSettle();
      expect(find.textContaining('already told me'), findsNothing);
    });

    testWidgets('does not stop the memory from being saved', (tester) async {
      final t = await makeService([existing]);
      await openScreen(tester, const AddMemoryScreen(), memories: t.service);

      await tester.enterText(mainField(), 'I lent Rahul 500 rupees');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Memory'));
      await tester.pumpAndSettle();

      expect(t.service.memories, hasLength(2));
    });
  });
}
