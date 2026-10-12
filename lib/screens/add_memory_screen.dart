import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/memory_service.dart';
import '../services/entity_extractor.dart';
import '../services/category_classifier.dart';
import '../services/attachment_service.dart';
import 'package:image_picker/image_picker.dart';

class AddMemoryScreen extends StatefulWidget {
  const AddMemoryScreen({super.key});

  @override
  State<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends State<AddMemoryScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final List<String> _attachments = [];
  bool _isSaving = false;
  bool _showOptions = false;
  String? _duplicateMessage;
  DateTime? _reminderAt;

  // Voice input variables
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;

  @override
  void dispose() {
    _textController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    setState(() {
      _duplicateMessage = null;
    });
    if (value.trim().length > 10) {
      _checkDuplicate(value);
    }
  }

  Future<void> _checkDuplicate(String text) async {
    final memoryService = context.read<MemoryService>();
    final result = await memoryService.checkDuplicate(text);
    if (mounted && result != null) {
      setState(() => _duplicateMessage = result);
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (mounted) setState(() => _isListening = false);
      },
    );

    if (available && mounted) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
          });
        },
      );
    }
  }

  Future<void> _save() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSaving) return;

    setState(() => _isSaving = true);
    final memoryService = context.read<MemoryService>();
    final saved = await memoryService.addMemory(
      text,
      reminderAt: _reminderAt,
      tags: _tagsController.text.split(','),
      attachmentPaths: _attachments,
    );
    if (mounted) setState(() => _isSaving = false);

    if (mounted && saved != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🧠 Memory saved!'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not save memory. Please try again.')),
      );
    }
  }

  Future<void> _addImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;
    final path = await AttachmentService.pickImage(source);
    if (path != null && mounted) setState(() => _attachments.add(path));
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      initialDate: _reminderAt ?? now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _reminderAt ?? now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    setState(() {
      _reminderAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = _textController.text.trim();
    final person = text.isNotEmpty ? EntityExtractor.extractPerson(text) : null;
    final amount = text.isNotEmpty ? EntityExtractor.extractAmount(text) : null;
    final date = text.isNotEmpty ? EntityExtractor.extractDate(text) : null;
    final location =
        text.isNotEmpty ? EntityExtractor.extractLocation(text) : null;
    final category = text.isNotEmpty ? CategoryClassifier.classify(text) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Memory'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🧠 What do you want me to remember?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _textController,
                    autofocus: true,
                    maxLines: 4,
                    onChanged: _onTextChanged,
                    decoration: InputDecoration(
                      hintText:
                          'e.g., "I lent Rahul ₹500 yesterday", "Priya\'s birthday is December 10"',
                      suffixIcon: IconButton(
                        onPressed: _toggleListening,
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening
                              ? Colors.red
                              : const Color(0xFF6750A4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showOptions = !_showOptions),
              icon: Icon(_showOptions ? Icons.expand_less : Icons.tune),
              label: Text(_showOptions
                  ? 'Hide options'
                  : 'Add tags, photo, or reminder'),
            ),
          ),
          if (_showOptions) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _tagsController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'e.g. Interview, Career, Ravi',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_attachments.isEmpty
                  ? 'Add photo or screenshot'
                  : '${_attachments.length} attachment(s) added'),
            ),
          ],
          if (text.length > 10 &&
              (person != null ||
                  amount != null ||
                  date != null ||
                  location != null)) ...[
            const SizedBox(height: 20),
            Text(
              '🔍 I understood:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (person != null)
                      _buildExtractedRow(context, '👤 Person', person),
                    if (amount != null)
                      _buildExtractedRow(context, '💰 Amount', '₹$amount'),
                    if (date != null)
                      _buildExtractedRow(context, '📅 Date', _formatDate(date)),
                    if (location != null)
                      _buildExtractedRow(context, '📍 Location', location),
                    if (category != null)
                      _buildExtractedRow(
                        context,
                        '📂 Category',
                        '${CategoryClassifier.getCategoryIcon(category)} ${CategoryClassifier.getCategoryLabel(category)}',
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (_duplicateMessage != null) ...[
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFFFFF3E0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Color(0xFFE65100)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _duplicateMessage!,
                        style: const TextStyle(color: Color(0xFFE65100)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_showOptions) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickReminder,
              icon: Icon(_reminderAt == null
                  ? Icons.notifications_outlined
                  : Icons.notifications_active_outlined),
              label: Text(_reminderAt == null
                  ? 'Add a reminder'
                  : 'Reminder: ${_formatDate(_reminderAt!.toIso8601String())}'),
            ),
            if (_reminderAt != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _reminderAt = null),
                  child: const Text('Remove reminder'),
                ),
              ),
          ],
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: text.isEmpty || _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_isSaving ? 'Saving...' : 'Save Memory'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6750A4),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
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
