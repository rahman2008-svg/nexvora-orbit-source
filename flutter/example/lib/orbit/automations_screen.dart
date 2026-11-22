import 'package:flutter/material.dart';

import 'action_registry.dart';
import 'orbit_controller.dart';
import 'orbit_theme.dart';
import 'workflow_engine.dart';
import 'orbit_store.dart';

/// Task Builder: describe a multi-step task, review the typed plan, run it with
/// per-step progress, cancel it, or save it as a workflow.
class AutomationsScreen extends StatefulWidget {
  const AutomationsScreen({super.key, required this.controller});
  final OrbitController controller;

  @override
  State<AutomationsScreen> createState() => _AutomationsScreenState();
}

class _AutomationsScreenState extends State<AutomationsScreen> {
  final TextEditingController _text = TextEditingController();
  List<OrbitAction>? _plan;
  String? _message; // parser question / not-found / info
  WorkflowRun? _run;
  bool _saveEnabled = true;

  OrbitController get c => widget.controller;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _build() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    final r = c.parser.parse(t);
    setState(() {
      _run = null;
      if (r == null) {
        _plan = null;
        _message = 'I couldn\u0027t turn that into supported actions. Try e.g. '
            '"open YouTube and then start a 30 minute timer".';
      } else if (r.plan.isNotEmpty) {
        _plan = r.plan;
        _message = null;
      } else if (r.question != null) {
        _plan = null;
        _message = '${r.question} (${r.choices.map((a) => a.label).join(', ')}). '
            'Say the app name, e.g. "open ${r.choices.first.label}".';
      } else {
        _plan = null;
        _message = r.notFound;
      }
    });
  }

  Future<void> _runIt() async {
    final plan = _plan;
    if (plan == null) return;
    final fut = c.runPlan(_text.text.trim(), plan, userText: _text.text.trim());
    setState(() => _run = c.engine.current);
    c.engine.current?.addListener(_tick);
    await fut;
    if (mounted) setState(() {});
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  void _save() {
    final plan = _plan;
    if (plan == null || c.store == null) return;
    final name = _text.text.trim();
    c.store!.saveWorkflow(name.length > 40 ? '${name.substring(0, 40)}…' : name, plan, enabled: _saveEnabled);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workflow saved on this device.')));
  }

  @override
  Widget build(BuildContext context) {
    final saved = c.store?.workflows() ?? const <SavedWorkflow>[];
    final plan = _plan;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Row(children: [
            Icon(Icons.bolt_rounded, color: OrbitColors.primary),
            SizedBox(width: 10),
            Text('Task Builder', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          const Text('Build multi-step tasks with one sentence.', style: TextStyle(color: OrbitColors.textDim)),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _build(),
            decoration: InputDecoration(
              hintText: 'e.g. Open YouTube, then start a 30 minute timer',
              suffixIcon: IconButton(icon: const Icon(Icons.auto_awesome), onPressed: _build),
            ),
          ),
          const SizedBox(height: 14),
          _pipeline(),
          const SizedBox(height: 14),
          if (_message != null)
            GlassCard(child: Text(_message!, style: const TextStyle(color: OrbitColors.warn))),
          if (plan != null) ...[
            const Text('Plan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (var i = 0; i < plan.length; i++) _stepTile(i, plan[i]),
            const SizedBox(height: 8),
            GlassCard(
              child: Row(children: [
                const Icon(Icons.bolt, color: OrbitColors.warn),
                const SizedBox(width: 10),
                const Expanded(child: Text('Save as workflow (enabled)')),
                Switch(value: _saveEnabled, onChanged: (v) => setState(() => _saveEnabled = v)),
              ]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: GradientButton(
                  label: c.engine.isRunning ? 'Running…' : 'Run now',
                  icon: Icons.play_arrow_rounded,
                  onPressed: c.engine.isRunning ? null : _runIt,
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
              ),
            ]),
          ],
          if (_run != null) ...[
            const SizedBox(height: 14),
            _runCard(_run!),
          ],
          const SizedBox(height: 22),
          const Text('Saved workflows', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (saved.isEmpty)
            const Text('None yet. Build a task above and tap Save.', style: TextStyle(color: OrbitColors.textDim)),
          for (final w in saved) _savedTile(w),
          const SizedBox(height: 10),
          const Text(
            'Workflows run only when you start them. ORBIT does not run tasks in the background '
            'or on a schedule without your action, and sensitive steps always ask first.',
            style: TextStyle(fontSize: 11.5, color: OrbitColors.textDim),
          ),
        ],
      ),
    );
  }

  Widget _pipeline() {
    const stages = [
      (Icons.psychology_alt_outlined, 'Understand request', 'Parse your command'),
      (Icons.search, 'Find supported action', 'Match typed actions & apps'),
      (Icons.verified_user_outlined, 'Ask permission', 'Confirm sensitive steps'),
      (Icons.play_circle_outline, 'Run action', 'Execute via Android intents'),
    ];
    final run = _run;
    int active = -1;
    if (run != null) {
      active = run.status == RunStatus.running ? 3 : 4;
    } else if (_plan != null) {
      active = 2;
    }
    return Column(children: [
      for (var i = 0; i < stages.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: i < active ? OrbitColors.ok : OrbitColors.surfaceHi,
                child: i < active
                    ? const Icon(Icons.check, size: 15, color: Colors.black)
                    : Text('${i + 1}', style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Icon(stages[i].$1, color: OrbitColors.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(stages[i].$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(stages[i].$3, style: const TextStyle(fontSize: 12, color: OrbitColors.textDim)),
                ]),
              ),
            ]),
          ),
        ),
    ]);
  }

  Widget _stepTile(int i, OrbitAction a) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GlassCard(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Text('${i + 1}', style: const TextStyle(color: OrbitColors.secondary, fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Expanded(child: Text(a.title)),
            if (a.risk == ActionRisk.confirm)
              const Tooltip(message: 'Asks before running', child: Icon(Icons.shield_outlined, size: 18, color: OrbitColors.warn)),
          ]),
        ),
      );

  Widget _runCard(WorkflowRun run) {
    IconData icon(StepStatus s) => switch (s) {
          StepStatus.done => Icons.check_circle,
          StepStatus.failed => Icons.error,
          StepStatus.running => Icons.hourglass_top,
          StepStatus.skipped => Icons.remove_circle_outline,
          StepStatus.cancelled => Icons.cancel_outlined,
          StepStatus.pending => Icons.radio_button_unchecked,
        };
    Color color(StepStatus s) => switch (s) {
          StepStatus.done => OrbitColors.ok,
          StepStatus.failed => OrbitColors.error,
          StepStatus.running => OrbitColors.secondary,
          _ => OrbitColors.textDim,
        };
    return GlassCard(
      glow: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Progress', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (run.status == RunStatus.running)
            TextButton(onPressed: c.engine.cancel, child: const Text('Cancel')),
        ]),
        for (final s in run.steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon(s.state), size: 18, color: color(s.state)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.action.title),
                  if (s.message.isNotEmpty)
                    Text(s.message, style: const TextStyle(fontSize: 12, color: OrbitColors.textDim)),
                ]),
              ),
            ]),
          ),
        if (run.summary.isNotEmpty) ...[
          const Divider(),
          Text(run.summary,
              style: TextStyle(color: run.status == RunStatus.failed ? OrbitColors.error : OrbitColors.text)),
        ],
      ]),
    );
  }

  Widget _savedTile(SavedWorkflow w) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(w.steps.map((s) => s.title).join('  →  '),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: OrbitColors.textDim)),
              ]),
            ),
            IconButton(
              tooltip: 'Run',
              icon: const Icon(Icons.play_circle_fill_rounded, color: OrbitColors.secondary),
              onPressed: !w.enabled || c.engine.isRunning
                  ? null
                  : () async {
                      setState(() {
                        _plan = w.steps;
                        _text.text = w.name;
                      });
                      await _runIt();
                    },
            ),
            Switch(
              value: w.enabled,
              onChanged: (v) {
                c.store?.setWorkflowEnabled(w.id, v);
                setState(() {});
              },
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                c.store?.deleteWorkflow(w.id);
                setState(() {});
              },
            ),
          ]),
        ),
      );
}
