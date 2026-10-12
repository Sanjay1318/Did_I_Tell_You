import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/memory_service.dart';
import 'memory_detail_screen.dart';
import '../widgets/memory_card.dart';
import '../services/category_classifier.dart';

class PersonScreen extends StatefulWidget {
  final String personName;

  const PersonScreen({super.key, required this.personName});

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  @override
  Widget build(BuildContext context) {
    final memoryService = context.watch<MemoryService>();
    final personMemories = memoryService.memories
        .where(
            (m) => m.person?.toLowerCase() == widget.personName.toLowerCase())
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final categories = <String, int>{};
    for (final memory in personMemories) {
      categories[memory.category] = (categories[memory.category] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.personName),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        const Color(0xFF6750A4).withValues(alpha: 0.1),
                    child: Text(
                      widget.personName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6750A4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.personName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${personMemories.length} memories',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              '📂 Categories',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.entries.map((entry) {
                    final color =
                        CategoryClassifier.getCategoryColor(entry.key);
                    return Chip(
                      avatar: Text(
                        CategoryClassifier.getCategoryIcon(entry.key),
                        style: const TextStyle(fontSize: 16),
                      ),
                      label: Text(
                        '${CategoryClassifier.getCategoryLabel(entry.key)} (${entry.value})',
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: color?.withValues(alpha: 0.08) ??
                          Colors.grey.shade100,
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            '🧠 All Memories',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          if (personMemories.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No memories about ${widget.personName} yet.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
            )
          else
            for (final memory in personMemories)
              MemoryCard(
                memory: memory,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MemoryDetailScreen(memory: memory),
                    ),
                  );
                },
              ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
