import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/memory.dart';
import '../services/memory_service.dart';
import '../widgets/memory_card.dart';
import 'memory_detail_screen.dart';

class ArchivedMemoriesScreen extends StatefulWidget {
  const ArchivedMemoriesScreen({super.key});

  @override
  State<ArchivedMemoriesScreen> createState() => _ArchivedMemoriesScreenState();
}

class _ArchivedMemoriesScreenState extends State<ArchivedMemoriesScreen> {
  late Future<List<Memory>> _archived;

  @override
  void initState() {
    super.initState();
    _archived = context.read<MemoryService>().getArchivedMemories();
  }

  void _reload() => setState(() {
        _archived = context.read<MemoryService>().getArchivedMemories();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archived memories')),
      body: FutureBuilder<List<Memory>>(
        future: _archived,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final memories = snapshot.data ?? [];
          if (memories.isEmpty) {
            return const Center(child: Text('No archived memories.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: memories.length,
            itemBuilder: (context, index) {
              final memory = memories[index];
              return Dismissible(
                key: ValueKey(memory.id),
                direction: DismissDirection.startToEnd,
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 24),
                  color: Colors.green,
                  child: const Icon(Icons.unarchive, color: Colors.white),
                ),
                confirmDismiss: (_) async =>
                    context.read<MemoryService>().restoreMemory(memory),
                onDismissed: (_) => _reload(),
                child: MemoryCard(
                  memory: memory,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemoryDetailScreen(memory: memory),
                      ),
                    );
                    _reload();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
