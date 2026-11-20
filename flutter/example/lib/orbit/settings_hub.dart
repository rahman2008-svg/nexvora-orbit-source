import 'package:flutter/material.dart';

import 'orbit_theme.dart';

/// Settings tab: shortcuts to the detailed (existing) settings panels plus
/// ORBIT-specific items (activity, assistant activation, licenses).
class SettingsHub extends StatelessWidget {
  const SettingsHub({
    super.key,
    required this.onOpenSettings,
    required this.onOpenActivity,
    required this.onAssistant,
    required this.onUpdates,
    required this.assistantActive,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onOpenActivity;
  final VoidCallback onAssistant;
  final VoidCallback onUpdates;
  final bool? assistantActive;

  static const String version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData i, String t, String sub, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            onTap: onTap,
            child: Row(children: [
              Icon(i, color: OrbitColors.secondary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(sub, style: const TextStyle(fontSize: 12, color: OrbitColors.textDim)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: OrbitColors.textDim),
            ]),
          ),
        );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          tile(Icons.history_rounded, 'Your Activity', 'History, saved workflows, memory controls', onOpenActivity),
          tile(Icons.tune_rounded, 'Models, voice, storage & more',
              'Language model, voice, documents, music, maps, reminders, storage', onOpenSettings),
          tile(Icons.assistant_rounded, 'Default assistant',
              assistantActive == true
                  ? 'ORBIT is your default assistant (power-button hold)'
                  : 'Make ORBIT the phone assistant (support varies by device)',
              onAssistant),
          tile(Icons.system_update_alt_rounded, 'Updates', 'Manual, opt-in update check', onUpdates),
          tile(Icons.gavel_rounded, 'About & open-source licenses', 'NexVora ORBIT $version', () {
            showLicensePage(
              context: context,
              applicationName: 'NexVora ORBIT',
              applicationVersion: version,
              applicationLegalese: '© 2026 NexVora Lab\u0027s Ofc. Built on the Eva app and the Cactus engine '
                  '(Cactus Compute, Inc.) — see the bundled licenses.',
            );
          }),
          const SizedBox(height: 10),
          const Text(
            'Your Phone. Your Intelligence.\nDeveloped by Prince AR Abdur Rahman · Published by NexVora Lab\u0027s Ofc',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: OrbitColors.textDim),
          ),
        ],
      ),
    );
  }
}
