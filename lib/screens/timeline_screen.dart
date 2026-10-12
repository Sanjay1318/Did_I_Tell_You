import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/memory_service.dart';
import 'memory_detail_screen.dart';
import '../widgets/memory_card.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final memoryService = context.watch<MemoryService>();
    final grouped = memoryService.groupMemoriesByDay();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: grouped.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📅', style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: 12),
                  Text(
                    'Your timeline will appear here',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final entry = grouped.entries.elementAt(index);
                final dateLabel = entry.key;
                final memories = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6750A4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateLabel,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '· ${memories.length}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final memory in memories)
                      MemoryCard(
                        memory: memory,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MemoryDetailScreen(memory: memory),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
    );
  }
}
