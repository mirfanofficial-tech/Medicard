import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../theme.dart';
import '../../ui/widgets.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsControllerProvider);
    final ctl = ref.read(settingsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Not delivered yet in this build'),
                  value: s.push,
                  onChanged: ctl.setPush,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Medication Reminders'),
                  value: s.medReminders,
                  onChanged: ctl.setMedReminders,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Biometric / Face ID unlock'),
                  subtitle: const Text('App-lock arrives in a later update'),
                  value: s.biometric,
                  onChanged: ctl.setBiometric,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Column(
              children: [
                MenuTile(icon: Icons.lock_outline, title: 'Change PIN', subtitle: 'Coming soon'),
                Divider(height: 1),
                MenuTile(icon: Icons.language, title: 'Language', subtitle: 'English'),
                Divider(height: 1),
                MenuTile(icon: Icons.brightness_6_outlined, title: 'Theme', subtitle: 'Light'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: MenuTile(
              icon: Icons.logout,
              iconColor: MediCardColors.danger,
              title: 'Logout',
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ),
        ],
      ),
    );
  }
}
