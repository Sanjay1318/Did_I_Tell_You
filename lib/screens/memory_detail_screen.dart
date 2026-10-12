import 'package:flutter/material.dart';
import 'dart:io';
import 'person_screen.dart';
import 'package:provider/provider.dart';
import '../models/memory.dart';
import '../services/memory_service.dart';
import '../services/category_classifier.dart';

class MemoryDetailScreen extends StatefulWidget {
  final Memory memory;

  const MemoryDetailScreen({super.key, required this.memory});

  @override
  State<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends State<MemoryDetailScreen> {
  bool _isEditing = false;
  late TextEditingController _editController;
  late Memory _currentMemory;

  @override
  void initState() {
    super.initState();
    _currentMemory = widget.memory;
    _editController = TextEditingController(text: widget.memory.originalText);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _saveEdit() async {
    final text = _editController.text.trim();
    if (text.isEmpty) return;
    final memoryService = context.read<MemoryService>();
    final updated = _currentMemory.copyWith(
      originalText: text,
      updatedAt: DateTime.now(),
    );
    final saved = await memoryService.updateMemory(updated);
    if (!saved || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not save changes. Please try again.')),
        );
      }
      return;
    }
    setState(() {
      _currentMemory = memoryService.memories
          .firstWhere((memory) => memory.id == _currentMemory.id);
      _isEditing = false;
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this memory?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final deleted =
          await context.read<MemoryService>().deleteMemory(_currentMemory.id!);
      if (mounted && deleted) Navigator.pop(context);
    }
  }

  Future<void> _togglePinned() async {
    final saved = await context
        .read<MemoryService>()
        .setPinned(_currentMemory, !_currentMemory.isPinned);
    if (saved && mounted) {
      setState(() => _currentMemory =
          _currentMemory.copyWith(isPinned: !_currentMemory.isPinned));
    }
  }

  Future<void> _archive() async {
    final saved =
        await context.read<MemoryService>().archiveMemory(_currentMemory);
    if (saved && mounted) Navigator.pop(context);
  }

  Future<void> _toggleSettlement() async {
    final status = _currentMemory.moneyStatus == 'settled' ? 'open' : 'settled';
    final saved = await context
        .read<MemoryService>()
        .setMoneyStatus(_currentMemory, status);
    if (saved && mounted) {
      setState(
          () => _currentMemory = _currentMemory.copyWith(moneyStatus: status));
    }
  }

  Future<void> _toggleTask() async {
    final status =
        _currentMemory.taskStatus == 'completed' ? 'pending' : 'completed';
    final saved = await context
        .read<MemoryService>()
        .setTaskStatus(_currentMemory, status);
    if (saved && mounted) {
      setState(
          () => _currentMemory = _currentMemory.copyWith(taskStatus: status));
    }
  }

  Future<void> _editTags() async {
    final controller =
        TextEditingController(text: _currentMemory.tags.join(', '));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit tags'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration:
              const InputDecoration(hintText: 'Separate tags with commas'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved == true && mounted) {
      final tags = controller.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList();
      final updated = _currentMemory.copyWith(tags: tags);
      final updatedSuccessfully = await context
          .read<MemoryService>()
          .updateMemory(updated, reanalyze: false);
      if (updatedSuccessfully && mounted)
        setState(() => _currentMemory = updated);
    }
    controller.dispose();
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final existing = DateTime.tryParse(_currentMemory.reminderAt ?? '');
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      initialDate: existing ?? now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay.fromDateTime(existing ?? now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    final reminder =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final saved = await context
        .read<MemoryService>()
        .setReminder(_currentMemory, reminder);
    if (saved && mounted) {
      setState(() => _currentMemory =
          _currentMemory.copyWith(reminderAt: reminder.toIso8601String()));
    }
  }

  Future<void> _editExtractedDetails() async {
    final person = TextEditingController(text: _currentMemory.person ?? '');
    final amount = TextEditingController(
        text: _currentMemory.amount?.toStringAsFixed(2) ?? '');
    final date = TextEditingController(
        text: _currentMemory.extractedDate?.split('T').first ?? '');
    final location = TextEditingController(text: _currentMemory.location ?? '');
    var category = _currentMemory.category;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Correct extracted details'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: person,
                  decoration: const InputDecoration(labelText: 'Person')),
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              TextField(
                controller: date,
                decoration:
                    const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
              ),
              TextField(
                  controller: location,
                  decoration: const InputDecoration(labelText: 'Location')),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: CategoryClassifier.getAllCategories()
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child:
                              Text(CategoryClassifier.getCategoryLabel(value)),
                        ))
                    .toList(),
                onChanged: (value) => setDialogState(() => category = value!),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      final rawDate = date.text.trim();
      final parsedDate = rawDate.isEmpty ? null : DateTime.tryParse(rawDate);
      if (rawDate.isNotEmpty && parsedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Use YYYY-MM-DD for the date.')),
        );
      } else {
        final updated = Memory(
          id: _currentMemory.id,
          originalText: _currentMemory.originalText,
          createdAt: _currentMemory.createdAt,
          updatedAt: DateTime.now(),
          category: category,
          person: person.text.trim().isEmpty ? null : person.text.trim(),
          amount: double.tryParse(amount.text.trim()),
          extractedDate: parsedDate?.toIso8601String(),
          location: location.text.trim().isEmpty ? null : location.text.trim(),
          status: _currentMemory.status,
          isPinned: _currentMemory.isPinned,
          reminderAt: _currentMemory.reminderAt,
          moneyStatus: _currentMemory.moneyStatus,
          metadata: _currentMemory.metadata,
        );
        final updatedSuccessfully = await context
            .read<MemoryService>()
            .updateMemory(updated, reanalyze: false);
        if (updatedSuccessfully && mounted) {
          setState(() => _currentMemory = updated);
        }
      }
    }
    person.dispose();
    amount.dispose();
    date.dispose();
    location.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memory = _currentMemory;
    final categoryColor =
        CategoryClassifier.getCategoryColor(memory.category) ?? Colors.grey;
    final categoryIcon = CategoryClassifier.getCategoryIcon(memory.category);
    final categoryLabel = CategoryClassifier.getCategoryLabel(memory.category);

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryLabel),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Memory actions',
            onSelected: (action) {
              switch (action) {
                case 'edit':
                  setState(() => _isEditing = !_isEditing);
                  break;
                case 'details':
                  _editExtractedDetails();
                  break;
                case 'tags':
                  _editTags();
                  break;
                case 'pin':
                  _togglePinned();
                  break;
                case 'archive':
                  _archive();
                  break;
                case 'delete':
                  _delete();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit memory')),
              const PopupMenuItem(
                  value: 'details', child: Text('Correct details')),
              const PopupMenuItem(value: 'tags', child: Text('Edit tags')),
              PopupMenuItem(
                value: 'pin',
                child: Text(memory.isPinned ? 'Unpin memory' : 'Pin memory'),
              ),
              const PopupMenuItem(
                  value: 'archive', child: Text('Archive memory')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'delete', child: Text('Delete memory')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(categoryIcon,
                            style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          categoryLabel,
                          style: TextStyle(
                            color: categoryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(memory.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_isEditing) ...[
                    TextField(
                      controller: _editController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Edit your memory...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _isEditing = false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _saveEdit,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ] else
                    Text(
                      memory.originalText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                ],
              ),
            ),
          ),
          if (memory.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  memory.tags.map((tag) => Chip(label: Text('#$tag'))).toList(),
            ),
          ],
          if (memory.attachmentPaths.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Attachments', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: memory.attachmentPaths.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(memory.attachmentPaths[index]),
                      width: 120,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                          width: 120,
                          child: Icon(Icons.broken_image_outlined))),
                ),
              ),
            ),
          ],
          if (memory.taskStatus != 'none') ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(memory.taskStatus == 'completed'
                    ? Icons.task_alt
                    : Icons.pending_actions),
                title: Text(memory.taskAction ?? 'Follow-up'),
                subtitle: Text(memory.taskStatus == 'completed'
                    ? 'Completed'
                    : 'Pending follow-up'),
                trailing: TextButton(
                  onPressed: _toggleTask,
                  child: Text(
                      memory.taskStatus == 'completed' ? 'Reopen' : 'Complete'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            '📋 Extracted Information',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow(
                      context, '👤 Person', memory.person ?? 'Not detected'),
                  const Divider(height: 16),
                  _buildInfoRow(
                      context,
                      '💰 Amount',
                      memory.amount != null
                          ? '₹${memory.amount}'
                          : 'Not detected'),
                  const Divider(height: 16),
                  _buildInfoRow(
                      context,
                      '📅 Date',
                      memory.extractedDate != null
                          ? _formatDate(DateTime.parse(memory.extractedDate!))
                          : 'Not detected'),
                  const Divider(height: 16),
                  _buildInfoRow(context, '📍 Location',
                      memory.location ?? 'Not detected'),
                  const Divider(height: 16),
                  _buildInfoRow(context, '📂 Category', categoryLabel),
                  const Divider(height: 16),
                  _buildInfoRow(
                      context, '🕐 Created', _formatFullDate(memory.createdAt)),
                ],
              ),
            ),
          ),
          if (memory.category == 'money') ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _toggleSettlement,
              icon: Icon(memory.moneyStatus == 'settled'
                  ? Icons.undo
                  : Icons.check_circle_outline),
              label: Text(memory.moneyStatus == 'settled'
                  ? 'Mark as open'
                  : 'Mark as settled'),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickReminder,
            icon: const Icon(Icons.notifications_outlined),
            label: Text(
                memory.reminderAt == null ? 'Add reminder' : 'Change reminder'),
          ),
          if (memory.person != null && memory.person!.isNotEmpty) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PersonScreen(personName: memory.person!),
                  ),
                );
              },
              icon: const Icon(Icons.person_outline),
              label: Text('View all memories about ${memory.person}'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6750A4),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final memoryDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(memoryDate).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return '${days[date.weekday - 1]}, ${_formatFullDate(date)}';
    }
    return _formatFullDate(date);
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
