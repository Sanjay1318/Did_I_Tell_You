import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

class AppLock extends StatefulWidget {
  final Widget child;
  const AppLock({super.key, required this.child});

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _unlocked = false;
  bool _attempted = false;

  Future<void> _unlock() async {
    try {
      final unlocked = await _auth.authenticate(
        localizedReason: 'Unlock your private memories',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (mounted) {
        setState(() {
          _unlocked = unlocked;
          _attempted = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _attempted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = context.watch<SettingsService>().appLockEnabled;
    if (!enabled || _unlocked) return widget.child;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              const Text('Your memories are locked'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _unlock,
                icon: const Icon(Icons.lock_open),
                label: const Text('Unlock'),
              ),
              if (_attempted) const SizedBox(height: 12),
              if (_attempted)
                const Text('Use your device screen lock to continue.',
                    textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
