import 'package:did_i_tell_you/widgets/empty_state.dart';
import 'package:did_i_tell_you/widgets/quick_action_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EmptyState shows its icon, title and message', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EmptyState(
          icon: '🤔',
          title: 'Nothing here',
          message: 'Add something first.',
        ),
      ),
    ));

    expect(find.text('🤔'), findsOneWidget);
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Add something first.'), findsOneWidget);
  });

  group('QuickActionCard', () {
    testWidgets('shows its icon, label and subtitle', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuickActionCard(
            icon: '🔍',
            label: 'Search',
            subtitle: 'Ask your memories',
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('🔍'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Ask your memories'), findsOneWidget);
    });

    testWidgets('calls onTap when pressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuickActionCard(
            icon: '🔍',
            label: 'Search',
            subtitle: 'Ask your memories',
            onTap: () => taps++,
          ),
        ),
      ));

      await tester.tap(find.text('Search'));
      expect(taps, 1);
    });

    testWidgets('cuts a long subtitle to one line', (tester) async {
      final long = List.filled(60, 'words').join(' ');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QuickActionCard(
              icon: '🔍', label: 'Search', subtitle: long, onTap: () {}),
        ),
      ));

      final text = tester.widget<Text>(find.text(long));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });
}
