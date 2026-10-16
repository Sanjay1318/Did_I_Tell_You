import 'package:did_i_tell_you/screens/memory_detail_screen.dart';
import 'package:did_i_tell_you/screens/timeline_screen.dart';
import 'package:did_i_tell_you/widgets/memory_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../database/db_test_support.dart' show makeMemory;
import '../helpers/fakes.dart';
import '../helpers/pump.dart';

void main() {
  testWidgets('with no memories it says the timeline is empty',
      (tester) async {
    final t = await makeService();
    await showScreen(tester, const TimelineScreen(), memories: t.service);

    expect(find.text('Your timeline will appear here'), findsOneWidget);
    expect(find.byType(MemoryCard), findsNothing);
  });

  testWidgets('groups memories under a heading per day with a count',
      (tester) async {
    final t = await makeService([
      makeMemory(text: 'first on the 5th', createdAt: DateTime(2026, 1, 5, 9)),
      makeMemory(text: 'second on the 5th', createdAt: DateTime(2026, 1, 5, 18)),
      makeMemory(text: 'only one on the 4th', createdAt: DateTime(2026, 1, 4, 12)),
    ]);
    await showScreen(tester, const TimelineScreen(), memories: t.service);

    expect(find.text('January 5, 2026'), findsOneWidget);
    expect(find.text('· 2'), findsOneWidget);
    expect(find.text('January 4, 2026'), findsOneWidget);
    expect(find.text('· 1'), findsOneWidget);
    expect(find.byType(MemoryCard), findsNWidgets(3));
    expect(find.text('Your timeline will appear here'), findsNothing);
  });

  testWidgets('newest day comes first', (tester) async {
    final t = await makeService([
      makeMemory(text: 'older', createdAt: DateTime(2026, 1, 4, 12)),
      makeMemory(text: 'newer', createdAt: DateTime(2026, 1, 5, 12)),
    ]);
    await showScreen(tester, const TimelineScreen(), memories: t.service);

    final newer = tester.getTopLeft(find.text('January 5, 2026')).dy;
    final older = tester.getTopLeft(find.text('January 4, 2026')).dy;
    expect(newer, lessThan(older));
  });

  testWidgets('tapping a memory opens its details', (tester) async {
    final t = await makeService([
      makeMemory(text: 'Parked at Forum Mall', createdAt: DateTime(2026, 1, 5)),
    ]);
    await showScreen(tester, const TimelineScreen(), memories: t.service);

    await tester.tap(find.text('Parked at Forum Mall'));
    await tester.pumpAndSettle();

    expect(find.byType(MemoryDetailScreen), findsOneWidget);
  });
}
