import 'package:flutter/material.dart';

import 'action_registry.dart';
import 'app_icon.dart';
import 'app_index.dart';
import 'orbit_controller.dart';
import 'orbit_native.dart';
import 'orbit_theme.dart';
import 'workflow_engine.dart';

/// "App Intelligence": discover installed apps, search by name or capability,
/// see what Android says each app can handle, favourite and launch them.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, required this.controller, this.focusSearch});
  final OrbitController controller;

  /// Bumped by the shell to focus the search box ("Find an app" quick action).
  final ValueNotifier<int>? focusSearch;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _q = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _cat = 'all';

  OrbitController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_rebuild);
    widget.focusSearch?.addListener(_focusSearch);
  }

  void _focusSearch() => _focus.requestFocus();
  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_rebuild);
    widget.focusSearch?.removeListener(_focusSearch);
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searching = _q.text.trim().isNotEmpty;
    _catSet = c.index.search('', category: _cat, limit: 100000).map((s) => s.app).toSet();
    final results = c.index.search(_q.text, category: _cat, limit: 60);
    final store = c.store;
    final favPkgs = store?.favorites() ?? const <String>[];
    final favs = favPkgs.map(c.index.byPackage).whereType<InstalledApp>().toList();
    final recent = (store?.recentLaunches() ?? const <String>[])
        .map(c.index.byPackage)
        .whereType<InstalledApp>()
        .toList();
    final discovered = [...c.index.apps]
      ..sort((a, b) => (b.installTime ?? 0).compareTo(a.installTime ?? 0));

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: c.refreshApps,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(children: [
              const Icon(Icons.grid_view_rounded, color: OrbitColors.secondary),
              const SizedBox(width: 10),
              const Text('App Intelligence', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                tooltip: 'Rescan apps',
                onPressed: c.indexing ? null : c.refreshApps,
                icon: c.indexing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _q,
              focusNode: _focus,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search apps or capability (e.g. "read PDFs")',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searching
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _q.clear()),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final t in AppIndex.categoryTabs)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t[0].toUpperCase() + t.substring(1)),
                        selected: _cat == t,
                        onSelected: (_) => setState(() => _cat = t),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (c.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(child: Text(c.error!, style: const TextStyle(color: OrbitColors.error))),
              ),
            if (c.index.apps.isEmpty && !c.indexing)
              const GlassCard(
                child: Text(
                  'No launchable apps found yet. Pull down to rescan. '
                  'ORBIT can only see apps that have a launcher entry.',
                  style: TextStyle(color: OrbitColors.textDim),
                ),
              )
            else if (searching) ...[
              _section('Results (${results.length})'),
              if (results.isEmpty)
                const Text('Nothing matches. Try a different word, e.g. "music", "pdf", "notes".',
                    style: TextStyle(color: OrbitColors.textDim)),
              for (final r in results) _resultTile(r),
            ] else ...[
              if (favs.isNotEmpty) ...[
                _section('Favorites'),
                _grid(favs.where((a) => _catMatch(a)).toList()),
              ],
              if (recent.isNotEmpty) ...[
                _section('Recently opened via ORBIT'),
                _grid(recent.where((a) => _catMatch(a)).toList()),
              ],
              _section('All apps (${c.index.apps.where(_catMatch).length})'),
              _grid(c.index.apps.where(_catMatch).toList()),
              _section('Recently discovered'),
              for (final a in discovered.where(_catMatch).take(4)) _appRow(a),
            ],
            const SizedBox(height: 8),
            const Text(
              'ORBIT lists apps with a launcher icon and the Android intents they declare '
              '(open PDFs, play audio, set timers…). It does not assume apps expose internal features.',
              style: TextStyle(fontSize: 11.5, color: OrbitColors.textDim),
            ),
          ],
        ),
      ),
    );
  }

  Set<InstalledApp> _catSet = {};
  bool _catMatch(InstalledApp a) => _catSet.contains(a);

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      );

  Widget _grid(List<InstalledApp> apps) => GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
        children: [for (final a in apps.take(24)) _tile(a)],
      );

  Widget _tile(InstalledApp a) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openSheet(a),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIconView(native: c.native, app: a, size: 48),
            const SizedBox(height: 6),
            Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );

  Widget _appRow(InstalledApp a, {String? why}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          onTap: () => _openSheet(a),
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            AppIconView(native: c.native, app: a, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(why == null || why.isEmpty ? c.index.describe(a) : 'Matched: $why',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: OrbitColors.textDim)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: OrbitColors.textDim),
          ]),
        ),
      );

  Widget _resultTile(ScoredApp r) => _appRow(r.app, why: r.why);

  void _openSheet(InstalledApp a) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OrbitColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => _AppSheet(controller: c, app: a),
    );
  }
}

class _AppSheet extends StatefulWidget {
  const _AppSheet({required this.controller, required this.app});
  final OrbitController controller;
  final InstalledApp app;

  @override
  State<_AppSheet> createState() => _AppSheetState();
}

class _AppSheetState extends State<_AppSheet> {
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final a = widget.app;
    final fav = c.store?.isFavorite(a.package) ?? false;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            AppIconView(native: c.native, app: a, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(a.package, style: const TextStyle(fontSize: 12, color: OrbitColors.textDim)),
              ]),
            ),
            IconButton(
              tooltip: fav ? 'Remove favorite' : 'Add favorite',
              icon: Icon(fav ? Icons.star_rounded : Icons.star_border_rounded,
                  color: fav ? OrbitColors.warn : OrbitColors.textDim),
              onPressed: () {
                c.store?.toggleFavorite(a.package);
                setState(() {});
                c.changed();
              },
            ),
          ]),
          const SizedBox(height: 14),
          Text(c.index.describe(a)),
          const SizedBox(height: 10),
          _kv('Version', a.versionName ?? 'unknown'),
          _kv('Type', a.system ? 'System app' : 'Installed app'),
          _kv('Launch activities', '${a.activities.length}'),
          if (a.intents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final i in a.intents)
                  Chip(label: Text(kIntentLabels[i] ?? i, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact),
              ]),
            ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Open ${a.label}',
            icon: Icons.open_in_new_rounded,
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              nav.pop();
              final run = await c.runPlan('Open ${a.label}', [OrbitAction.openApp(a.package, label: a.label)],
                  userText: 'Open ${a.label}');
              if (run.status != RunStatus.completed) {
                messenger.showSnackBar(SnackBar(content: Text(run.summary)));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 130, child: Text(k, style: const TextStyle(color: OrbitColors.textDim, fontSize: 12.5))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5))),
        ]),
      );
}
