import 'package:flutter/material.dart';

import 'orbit_controller.dart';
import 'orbit_store.dart';
import 'orbit_theme.dart';

String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

/// "Your Activity": command history, saved workflows, and memory controls.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.controller, this.onClearChats, this.chatCount});
  final OrbitController controller;

  /// Clears the assistant's saved conversations (owned by ChatStore in main.dart).
  final Future<void> Function()? onClearChats;
  final int? chatCount;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  OrbitController get c => widget.controller;
  OrbitStore? get s => c.store;

  Future<void> _confirm(String title, String body, VoidCallback onYes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      onYes();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your Activity'),
          bottom: const TabBar(
            indicatorColor: OrbitColors.secondary,
            tabs: [Tab(text: 'History'), Tab(text: 'Saved'), Tab(text: 'Preferences')],
          ),
        ),
        body: TabBarView(children: [_history(), _saved(), _prefs()]),
      ),
    );
  }

  Widget _history() {
    final list = s?.recentCommands(limit: 100) ?? const <CommandRecord>[];
    if (list.isEmpty) {
      return const Center(child: Text('No commands yet.', style: TextStyle(color: OrbitColors.textDim)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = list[i];
        final color = switch (r.status) {
          'ok' => OrbitColors.ok,
          'failed' => OrbitColors.error,
          _ => OrbitColors.textDim,
        };
        return Dismissible(
          key: ValueKey(r.id),
          background: Container(color: OrbitColors.error.withValues(alpha: 0.3)),
          onDismissed: (_) {
            s?.deleteCommand(r.id);
            setState(() {});
          },
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.circle, size: 10, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.text, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (r.message.isNotEmpty)
                    Text(r.message, maxLines: 3, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: OrbitColors.textDim)),
                ]),
              ),
              Text(ago(r.ts), style: const TextStyle(fontSize: 11.5, color: OrbitColors.textDim)),
            ]),
          ),
        );
      },
    );
  }

  Widget _saved() {
    final fav = s?.favorites() ?? const <String>[];
    final wf = s?.workflows() ?? const <SavedWorkflow>[];
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Saved workflows', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (wf.isEmpty) const Text('None.', style: TextStyle(color: OrbitColors.textDim)),
      for (final w in wf)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(w.steps.map((a) => a.title).join(' → '),
                      style: const TextStyle(fontSize: 12, color: OrbitColors.textDim)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.play_circle_fill_rounded, color: OrbitColors.secondary),
                onPressed: w.enabled
                    ? () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final r = await c.runPlan(w.name, w.steps, userText: w.name);
                        messenger.showSnackBar(SnackBar(content: Text(r.summary.isEmpty ? 'Done.' : r.summary)));
                        if (mounted) setState(() {});
                      }
                    : null,
              ),
            ]),
          ),
        ),
      const SizedBox(height: 16),
      const Text('Favorite apps', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (fav.isEmpty) const Text('None. Star an app in Explore.', style: TextStyle(color: OrbitColors.textDim)),
      for (final p in fav)
        ListTile(
          dense: true,
          leading: const Icon(Icons.star_rounded, color: OrbitColors.warn),
          title: Text(c.index.byPackage(p)?.label ?? p),
          subtitle: Text(p, style: const TextStyle(fontSize: 11)),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              s?.toggleFavorite(p);
              setState(() {});
            },
          ),
        ),
    ]);
  }

  Widget _prefs() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      GlassCard(
        glow: true,
        child: Row(children: [
          const Icon(Icons.verified_user_rounded, color: OrbitColors.ok, size: 36),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Stored on this device', style: TextStyle(fontWeight: FontWeight.w700, color: OrbitColors.ok)),
              Text('No account, no cloud upload, no analytics. Internet is used only when you '
                  'download a model, map tiles or other optional content.',
                  style: TextStyle(fontSize: 12.5, color: OrbitColors.textDim)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      const Text('Memory controls', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      _tile(Icons.history, 'Clear command history', 'Removes the list in the History tab.',
          () => _confirm('Clear command history?', 'This cannot be undone.', () => s?.clearCommands())),
      _tile(Icons.bolt, 'Delete saved workflows', 'Removes every saved workflow.',
          () => _confirm('Delete all workflows?', 'This cannot be undone.', () => s?.clearWorkflows())),
      _tile(Icons.star_border, 'Clear favorites & recent launches', 'Resets app favorites and "recently opened".',
          () => _confirm('Clear favorites and recents?', 'This cannot be undone.', () => s?.clearLaunchesAndFavorites())),
      if (widget.onClearChats != null)
        _tile(Icons.chat_bubble_outline, 'Delete all conversations', 'Removes every saved assistant chat.',
            () => _confirm('Delete all conversations?', 'This cannot be undone.', () async {
                  await widget.onClearChats!();
                })),
      _tile(Icons.delete_forever_outlined, 'Erase everything ORBIT remembers about actions',
          'History, workflows, favorites and preferences.',
          () => _confirm('Erase all action data?', 'History, workflows, favorites and preferences are deleted.',
              () => s?.clearAll())),
    ]);
  }

  Widget _tile(IconData i, String t, String sub, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          onTap: onTap,
          child: Row(children: [
            Icon(i, color: OrbitColors.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(sub, style: const TextStyle(fontSize: 12, color: OrbitColors.textDim)),
              ]),
            ),
          ]),
        ),
      );
}
