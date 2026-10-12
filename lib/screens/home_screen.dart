import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/memory_service.dart';
import '../widgets/memory_card.dart';
import 'add_memory_screen.dart';
import 'all_memories_screen.dart';
import 'memory_detail_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final memories = context.watch<MemoryService>().memories;
    final recent = memories.take(3).toList();
    final pending = memories
        .where((memory) => memory.taskStatus == 'pending')
        .take(2)
        .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddMemoryScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New memory'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Text(_greeting(), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'What would you like to remember?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            _AskMemoryCard(),
            const SizedBox(height: 16),
            _CaptureCard(),
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 28),
              _SectionHeader(title: 'Follow-ups', count: pending.length),
              const SizedBox(height: 8),
              for (final memory in pending)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.pending_actions_outlined),
                    title: Text(memory.taskAction ?? memory.originalText),
                    subtitle: Text(memory.person == null
                        ? 'Pending'
                        : 'With ${memory.person}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemoryDetailScreen(memory: memory),
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(child: _SectionHeader(title: 'Recent memories')),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AllMemoriesScreen()),
                  ),
                  child: const Text('View all'),
                ),
              ],
            ),
            if (recent.isEmpty)
              const _EmptyRecent()
            else
              for (final memory in recent)
                MemoryCard(
                  memory: memory,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MemoryDetailScreen(memory: memory),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _AskMemoryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        ),
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Row(children: [
            Icon(Icons.auto_awesome_outlined),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ask your memory',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 3),
                  Text('Did I tell Ravi about my interview?'),
                ],
              ),
            ),
            Icon(Icons.arrow_forward),
          ]),
        ),
      ),
    );
  }
}

class _CaptureCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddMemoryScreen()),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        alignment: Alignment.centerLeft,
      ),
      icon: const Icon(Icons.mic_none_outlined),
      label: const Text('Capture a memory by text, voice, or photo'),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  const _SectionHeader({required this.title, this.count});

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (count != null) ...[
          const SizedBox(width: 8),
          Badge(label: Text('$count')),
        ],
      ]);
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Icon(Icons.lightbulb_outline, size: 32),
            const SizedBox(height: 10),
            Text('Your memories will appear here',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            const Text('Save a thought, promise, place, or useful detail.'),
          ]),
        ),
      );
}
