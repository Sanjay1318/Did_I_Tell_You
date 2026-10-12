import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/memory_service.dart';
import '../services/export_service.dart';
import '../services/settings_service.dart';
import 'archived_memories_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final memoryService = context.watch<MemoryService>();
    final settings = context.watch<SettingsService>();
    final memoryCount = memoryService.memories.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage, color: Color(0xFF6750A4)),
              title: const Text('Total Memories'),
              subtitle: Text('$memoryCount memories stored'),
              trailing: Text('$memoryCount',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark mode'),
                  subtitle: const Text('Use a darker color scheme'),
                  value: settings.darkMode,
                  onChanged: settings.setDarkMode,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline),
                  title: const Text('App lock'),
                  subtitle:
                      const Text('Require device authentication at launch'),
                  value: settings.appLockEnabled,
                  onChanged: settings.setAppLockEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline, color: Colors.green),
              title: const Text('Privacy'),
              subtitle: const Text('All data is stored locally on this device'),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.archive_outlined, color: Colors.orange),
                  title: const Text('Archived memories'),
                  subtitle: const Text(
                      'Restore or permanently review archived items'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ArchivedMemoriesScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.share, color: Colors.blue),
                  title: const Text('Export as JSON'),
                  subtitle: const Text('Share a full backup'),
                  onTap: () async {
                    if (memoryCount == 0) return;
                    await ExportService.exportToJson(memoryService.memories);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.upload_file, color: Colors.blue),
                  title: const Text('Import JSON backup'),
                  subtitle: const Text('Restore memories from a prior export'),
                  onTap: () async {
                    try {
                      final backup = await ExportService.pickJsonBackup();
                      if (backup == null || !context.mounted) return;
                      final imported = await context
                          .read<MemoryService>()
                          .importMemories(backup);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('$imported memories imported.'),
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    } on FormatException catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(error.message),
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('Could not import that backup.'),
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.table_chart, color: Colors.blue),
                  title: const Text('Export as CSV'),
                  subtitle: const Text('Spreadsheet-friendly export'),
                  onTap: () async {
                    if (memoryCount == 0) return;
                    await ExportService.exportToCsv(memoryService.memories);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined,
                      color: Colors.red),
                  title: const Text('Delete All Memories'),
                  subtitle: const Text('Permanently remove all data'),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete all memories?'),
                        content: const Text(
                            'This will permanently delete all your memories. This cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.red),
                            child: const Text('Delete All'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      final deleted = await context
                          .read<MemoryService>()
                          .deleteAllMemories();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(deleted
                                ? 'All memories deleted.'
                                : 'Could not delete memories. Please try again.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Text('🧠', style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: 8),
                Text(
                  'Did I Already Tell You?',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your brain is for living life.\nTell it once. Remember it whenever you need it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'v1.0.0 — Local First',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
