import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/memory_service.dart';
import '../models/memory.dart';
import '../services/category_classifier.dart';
import '../services/search_answer.dart';
import 'memory_detail_screen.dart';
import '../widgets/memory_card.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Memory> _searchResults = [];
  bool _hasSearched = false;
  String _answer = '';
  String? _category;
  String? _person;
  DateTimeRange? _dateRange;
  double? _minimumAmount;
  double? _maximumAmount;
  String _sort = 'Newest';

  // Text-to-speech variables
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    final memoryService = context.read<MemoryService>();
    final base = query.trim().isEmpty
        ? memoryService.memories
        : memoryService.parseNaturalQuery(query.trim());
    final results = _applyFilters(base);
    final answer = SearchAnswer.generate(query, results);

    setState(() {
      _searchResults = results;
      _hasSearched = true;
      _answer = answer;
    });
  }

  List<Memory> _applyFilters(List<Memory> source) {
    final results = source.where((memory) {
      if (_category != null && memory.category != _category) return false;
      if (_person != null && memory.person != _person) return false;
      if (_minimumAmount != null &&
          (memory.amount == null || memory.amount! < _minimumAmount!)) {
        return false;
      }
      if (_maximumAmount != null &&
          (memory.amount == null || memory.amount! > _maximumAmount!)) {
        return false;
      }
      if (_dateRange != null &&
          (memory.createdAt.isBefore(_dateRange!.start) ||
              memory.createdAt
                  .isAfter(_dateRange!.end.add(const Duration(days: 1))))) {
        return false;
      }
      return true;
    }).toList();
    switch (_sort) {
      case 'Oldest':
        results.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case 'Amount: high to low':
        results.sort((a, b) => (b.amount ?? -1).compareTo(a.amount ?? -1));
      case 'Amount: low to high':
        results.sort((a, b) => (a.amount ?? double.infinity)
            .compareTo(b.amount ?? double.infinity));
      default:
        results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return results;
  }

  Future<void> _showFilters() async {
    final service = context.read<MemoryService>();
    final min = TextEditingController(text: _minimumAmount?.toString() ?? '');
    final max = TextEditingController(text: _maximumAmount?.toString() ?? '');
    var category = _category;
    var person = _person;
    var dateRange = _dateRange;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Wrap(children: [
            Row(children: [
              const Expanded(
                  child: Text('Filter memories',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
              TextButton(
                  onPressed: () => setSheetState(() {
                        category = null;
                        person = null;
                        dateRange = null;
                        min.clear();
                        max.clear();
                      }),
                  child: const Text('Clear')),
            ]),
            DropdownButtonFormField<String?>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('All categories')),
                ...CategoryClassifier.getAllCategories().map((value) =>
                    DropdownMenuItem(
                        value: value,
                        child:
                            Text(CategoryClassifier.getCategoryLabel(value))))
              ],
              onChanged: (value) => setSheetState(() => category = value),
            ),
            DropdownButtonFormField<String?>(
              initialValue: person,
              decoration: const InputDecoration(labelText: 'Person'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All people')),
                ...service.getAllPersons().map((value) =>
                    DropdownMenuItem(value: value, child: Text(value)))
              ],
              onChanged: (value) => setSheetState(() => person = value),
            ),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: min,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Minimum amount'))),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                      controller: max,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Maximum amount'))),
            ]),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(dateRange == null
                  ? 'Any date'
                  : '${dateRange!.start.toLocal().toString().split(' ').first} – ${dateRange!.end.toLocal().toString().split(' ').first}'),
              trailing: const Icon(Icons.date_range),
              onTap: () async {
                final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now());
                if (picked != null) setSheetState(() => dateRange = picked);
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() {
                  _category = category;
                  _person = person;
                  _dateRange = dateRange;
                  _minimumAmount = double.tryParse(min.text);
                  _maximumAmount = double.tryParse(max.text);
                });
                Navigator.pop(context);
                _performSearch(_searchController.text);
              },
              child: const Text('Apply filters'),
            ),
          ]),
        ),
      ),
    );
    min.dispose();
    max.dispose();
  }

  Future<void> _speakAnswer() async {
    if (_answer.isEmpty) return;
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.speak(_answer);
    setState(() => _isSpeaking = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Ask me anything... e.g., "Who owes me money?"',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: _performSearch,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => _performSearch(_searchController.text),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6750A4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _showFilters,
                  icon: const Icon(Icons.tune),
                  label: Text((_category != null ||
                          _person != null ||
                          _dateRange != null ||
                          _minimumAmount != null ||
                          _maximumAmount != null)
                      ? 'Filters active'
                      : 'Filters'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _sort,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Sort'),
                    items: const [
                      DropdownMenuItem(value: 'Newest', child: Text('Newest')),
                      DropdownMenuItem(value: 'Oldest', child: Text('Oldest')),
                      DropdownMenuItem(
                          value: 'Amount: high to low',
                          child: Text('Amount: high to low')),
                      DropdownMenuItem(
                          value: 'Amount: low to high',
                          child: Text('Amount: low to high')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _sort = value);
                      _performSearch(_searchController.text);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_answer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                color: const Color(0xFFE8F5E9),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _answer,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _speakAnswer,
                        icon: Icon(
                          _isSpeaking ? Icons.stop : Icons.volume_up,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: !_hasSearched
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🔍',
                            style: Theme.of(context).textTheme.displayMedium),
                        const SizedBox(height: 12),
                        Text(
                          'Search your memories naturally',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try: "Who owes me money?", "What do I know about Rahul?", "Where did I park?"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🤔',
                                style:
                                    Theme.of(context).textTheme.displayMedium),
                            const SizedBox(height: 12),
                            Text(
                              'No memories found',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final memory = _searchResults[index];
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
