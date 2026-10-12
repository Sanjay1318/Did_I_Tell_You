import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/memory_service.dart';
import '../services/category_classifier.dart';
import 'memory_detail_screen.dart';
import '../widgets/memory_card.dart';

class AllMemoriesScreen extends StatefulWidget {
  const AllMemoriesScreen({super.key});

  @override
  State<AllMemoriesScreen> createState() => _AllMemoriesScreenState();
}

class _AllMemoriesScreenState extends State<AllMemoriesScreen> {
  String? _selectedCategory;
  String? _selectedPerson;

  @override
  Widget build(BuildContext context) {
    final memoryService = context.watch<MemoryService>();
    final allCategories = CategoryClassifier.getAllCategories();
    final persons = memoryService.getAllPersons();

    var filteredMemories = memoryService.memories;
    if (_selectedCategory != null) {
      filteredMemories = filteredMemories
          .where((m) => m.category == _selectedCategory)
          .toList();
    }
    if (_selectedPerson != null) {
      filteredMemories =
          filteredMemories.where((m) => m.person == _selectedPerson).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Memories'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_selectedCategory != null || _selectedPerson != null)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear filters',
              onPressed: () {
                setState(() {
                  _selectedCategory = null;
                  _selectedPerson = null;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedCategory,
                    isExpanded: true,
                    hint: const Text('Category'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All categories'),
                      ),
                      ...allCategories.map((cat) {
                        return DropdownMenuItem<String?>(
                          value: cat,
                          child: Text(
                            '${CategoryClassifier.getCategoryIcon(cat)} ${CategoryClassifier.getCategoryLabel(cat)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedPerson,
                    isExpanded: true,
                    hint: const Text('Person'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All people'),
                      ),
                      ...persons.map((person) {
                        return DropdownMenuItem<String?>(
                          value: person,
                          child: Text(
                            person,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedPerson = value);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Result count
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Text(
                  '${filteredMemories.length} ${filteredMemories.length == 1 ? 'memory' : 'memories'}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // List
          Expanded(
            child: filteredMemories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '📭',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No memories found',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try changing the filters above',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: filteredMemories.length,
                    itemBuilder: (context, index) {
                      final memory = filteredMemories[index];
                      return MemoryCard(
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
