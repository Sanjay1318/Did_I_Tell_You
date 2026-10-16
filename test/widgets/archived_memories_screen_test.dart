import 'package:did_i_tell_you/screens/archived_memories_screen.dart';
import 'package:did_i_tell_you/screens/memory_detail_screen.dart';
import 'package:did_i_tell_you/widgets/memory_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../database/db_test_support.dart' show makeMemory;
import '../helpers/fakes.dart';
import '../helpers/pump.dart';

void main() {
  testWidgets('with nothing archived it says so', (tester) async {
    final t = await makeService([makeMemory(text: 'still active')]);
    await showScreen(tester, const ArchivedMemoriesScreen(),
        memories: t.service);

    expect(find.text('No archived memories.'), findsOneWidget);
    expect(find.text('still active'), findsNothing);
  });

  testWidgets('lists archived memories only', (tester) async {
    final t = await makeService([
      makeMemory(text: 'old parking spot', status: 'archived'),
      makeMemory(text: 'old gift idea', status: 'archived'),
      makeMemory(text: 'still active'),
    ]);
    await showScreen(tester, const ArchivedMemoriesScreen(),
        memories: t.service);

    expect(find.byType(MemoryCard), findsNWidgets(2));
    expect(find.text('old parking spot'), findsOneWidget);
    expect(find.text('old gift idea'), findsOneWidget);
    expect(find.text('still active'), findsNothing);
  });

  testWidgets('swiping a memory right restores it', (tester) async {
    final t = await makeService([
      makeMemory(id: 1, text: 'old parking spot', status: 'archived'),
    ]);
    await showScreen(tester, const ArchivedMemoriesScreen(),
        memories: t.service);

    await tester.drag(find.text('old parking spot'), const Offset(800, 0));
    await tester.pumpAndSettle();

    expect(t.service.memories.map((m) => m.originalText), ['old parking spot']);
    expect(t.db.rows.single.status, 'active');
    expect(find.text('No archived memories.'), findsOneWidget);
  });

  testWidgets('swiping left does nothing', (tester) async {
    final t = await makeService([
      makeMemory(id: 1, text: 'old parking spot', status: 'archived'),
    ]);
    await showScreen(tester, const ArchivedMemoriesScreen(),
        memories: t.service);

    await tester.drag(find.text('old parking spot'), const Offset(-800, 0));
    await tester.pumpAndSettle();

    expect(find.text('old parking spot'), findsOneWidget);
    expect(t.db.rows.single.status, 'archived');
  });

  testWidgets('tapping a memory opens its details', (tester) async {
    final t = await makeService([
      makeMemory(id: 1, text: 'old parking spot', status: 'archived'),
    ]);
    await showScreen(tester, const ArchivedMemoriesScreen(),
        memories: t.service);

    await tester.tap(find.text('old parking spot'));
    await tester.pumpAndSettle();

    expect(find.byType(MemoryDetailScreen), findsOneWidget);
  });
}
