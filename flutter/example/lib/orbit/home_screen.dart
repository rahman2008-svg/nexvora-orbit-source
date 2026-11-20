import 'package:flutter/material.dart';

import 'activity_screen.dart' show ago;
import 'orbit_controller.dart';
import 'orbit_theme.dart';

/// ORBIT Home: animated orb, greeting, availability, voice + text entry, quick
/// actions, library shortcuts and recent activity.
class OrbitHome extends StatefulWidget {
  const OrbitHome({
    super.key,
    required this.controller,
    required this.modelReady,
    required this.modelStatus,
    required this.listening,
    required this.generating,
    required this.onSubmit,
    required this.onMic,
    required this.onOpenApp,
    required this.onFindApp,
    required this.onTimer,
    required this.onOpenActivity,
    required this.onOpenImages,
    required this.onOpenMusic,
    required this.onOpenDocs,
    required this.onOpenMaps,
  });

  final OrbitController controller;
  final bool modelReady;
  final String modelStatus;
  final bool listening;
  final bool generating;
  final ValueChanged<String> onSubmit;
  final VoidCallback onMic;
  final VoidCallback onOpenApp;
  final VoidCallback onFindApp;
  final VoidCallback onTimer;
  final VoidCallback onOpenActivity;
  final VoidCallback onOpenImages;
  final VoidCallback onOpenMusic;
  final VoidCallback onOpenDocs;
  final VoidCallback onOpenMaps;

  @override
  State<OrbitHome> createState() => _OrbitHomeState();
}

class _OrbitHomeState extends State<OrbitHome> {
  final TextEditingController _t = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_r);
  }

  void _r() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_r);
    _t.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _submit() {
    final t = _t.text.trim();
    if (t.isEmpty) return;
    _t.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onSubmit(t);
  }

  @override
  Widget build(BuildContext context) {
    final recent = widget.controller.store?.recentCommands(limit: 3) ?? const [];
    final mode = widget.listening
        ? OrbMode.listening
        : (widget.generating ? OrbMode.thinking : OrbMode.idle);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          Row(children: [
            Image.asset('assets/orbit_avatar.png', width: 34, height: 34),
            const SizedBox(width: 10),
            const Text('NexVora ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ShaderMask(
              shaderCallback: (r) => OrbitColors.brand.createShader(r),
              child: const Text('ORBIT',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Your activity',
              onPressed: widget.onOpenActivity,
              icon: const Icon(Icons.history_rounded, color: OrbitColors.textDim),
            ),
          ]),
          const SizedBox(height: 6),
          Center(child: Text(_greeting, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700))),
          const SizedBox(height: 4),
          Center(
            child: Text(
              widget.modelReady ? 'ORBIT is ready' : widget.modelStatus,
              style: TextStyle(color: widget.modelReady ? OrbitColors.secondary : OrbitColors.warn),
            ),
          ),
          const SizedBox(height: 6),
          Center(child: OrbitOrb(size: 230, mode: mode)),
          Center(
            child: GestureDetector(
              onTap: widget.onMic,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [OrbitColors.primary, Color(0xFF4F46FF)]),
                  boxShadow: [BoxShadow(color: OrbitColors.primary.withValues(alpha: 0.6), blurRadius: 22)],
                ),
                child: Icon(widget.listening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white, size: 30),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _t,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Ask ORBIT anything…',
              suffixIcon: IconButton(
                icon: const Icon(Icons.send_rounded, color: OrbitColors.secondary),
                onPressed: _submit,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _quick(Icons.rocket_launch_outlined, 'Open app', widget.onOpenApp)),
            const SizedBox(width: 10),
            Expanded(child: _quick(Icons.search_rounded, 'Find an app', widget.onFindApp)),
            const SizedBox(width: 10),
            Expanded(child: _quick(Icons.timer_outlined, 'Start timer', widget.onTimer)),
          ]),
          const SizedBox(height: 18),
          const Text('Your library', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _quick(Icons.library_music_outlined, 'Music', widget.onOpenMusic)),
            const SizedBox(width: 10),
            Expanded(child: _quick(Icons.menu_book_outlined, 'Documents', widget.onOpenDocs)),
            const SizedBox(width: 10),
            Expanded(child: _quick(Icons.photo_library_outlined, 'Photos', widget.onOpenImages)),
            const SizedBox(width: 10),
            Expanded(child: _quick(Icons.map_outlined, 'Maps', widget.onOpenMaps)),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            const Text('Recent activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(onPressed: widget.onOpenActivity, child: const Text('See all')),
          ]),
          if (recent.isEmpty)
            const Text('Nothing yet. Try "open calculator".', style: TextStyle(color: OrbitColors.textDim)),
          for (final r in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Icon(r.status == 'ok' ? Icons.check_circle : Icons.info_outline,
                      size: 18, color: r.status == 'ok' ? OrbitColors.ok : OrbitColors.textDim),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r.text, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text(ago(r.ts), style: const TextStyle(fontSize: 11.5, color: OrbitColors.textDim)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _quick(IconData i, String label, VoidCallback onTap) => GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(children: [
          Icon(i, color: OrbitColors.secondary, size: 26),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5)),
        ]),
      );
}
