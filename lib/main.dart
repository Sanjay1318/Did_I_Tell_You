import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/database_service.dart';
import 'services/memory_service.dart';
import 'services/reminder_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local notifications
  await ReminderService.instance.initialize();

  final dbService = DatabaseService();
  await dbService.initDatabase();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MemoryService(dbService)..loadMemories(),
        ),
        ChangeNotifierProvider(create: (_) => SettingsService()..load()),
      ],
      child: const MemoryApp(),
    ),
  );
}
