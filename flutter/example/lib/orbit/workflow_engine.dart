import 'package:flutter/foundation.dart';

import 'action_registry.dart';
import 'orbit_native.dart';
import 'orbit_store.dart';

enum StepStatus { pending, running, done, failed, skipped, cancelled }

class StepProgress {
  StepProgress(this.action);
  final OrbitAction action;
  StepStatus state = StepStatus.pending;
  String message = '';
}

enum RunStatus { idle, running, completed, failed, cancelled }

/// Live, observable state of one run (drives the Task Builder UI).
class WorkflowRun extends ChangeNotifier {
  WorkflowRun(this.title, List<OrbitAction> plan) : steps = plan.map(StepProgress.new).toList();
  final String title;
  final List<StepProgress> steps;
  RunStatus status = RunStatus.idle;
  String summary = '';

  void touch() => notifyListeners();
}

typedef ConfirmCallback = Future<bool> Function(OrbitAction action);

/// Sequential, cancellable executor for typed action plans.
///
/// Rules (see ARCHITECTURE.md):
///  * every step is validated before it runs;
///  * `ActionRisk.confirm` steps need the user's explicit OK;
///  * the first failure stops the run (later steps are "skipped");
///  * the summary only ever says what Android reported — "asked the Clock app
///    to…" — never that a downstream app finished its work.
class WorkflowEngine {
  WorkflowEngine({
    required this.runner,
    required this.confirm,
    this.store,
    this.stepDelay = const Duration(milliseconds: 900),
    this.onLaunch,
  });

  final ActionRunner runner;
  final ConfirmCallback confirm;
  final OrbitStore? store;
  final Duration stepDelay;
  final void Function(String package)? onLaunch;

  bool _cancel = false;
  WorkflowRun? current;

  bool get isRunning => current?.status == RunStatus.running;

  void cancel() => _cancel = true;

  Future<WorkflowRun> run(String title, List<OrbitAction> plan, {String? userText}) async {
    final run = WorkflowRun(title, plan);
    current = run;
    _cancel = false;
    run.status = RunStatus.running;
    run.touch();

    var failed = false;
    var cancelled = false;
    var anyDone = false;
    for (var i = 0; i < run.steps.length; i++) {
      final step = run.steps[i];
      if (failed || cancelled) {
        step.state = failed ? StepStatus.skipped : StepStatus.cancelled;
        run.touch();
        continue;
      }
      if (_cancel) {
        cancelled = true;
        step.state = StepStatus.cancelled;
        run.touch();
        continue;
      }
      final err = step.action.validate();
      if (err != null) {
        step.state = StepStatus.failed;
        step.message = err;
        failed = true;
        run.touch();
        continue;
      }
      if (step.action.risk == ActionRisk.confirm) {
        final ok = await confirm(step.action);
        if (!ok) {
          step.state = StepStatus.cancelled;
          step.message = 'Not confirmed — nothing was done.';
          cancelled = true;
          run.touch();
          continue;
        }
      }
      step.state = StepStatus.running;
      run.touch();
      ActionOutcome out;
      try {
        out = await runner.run(step.action);
      } catch (e) {
        out = ActionOutcome(false, 'exception', 'Unexpected error: $e');
      }
      step.message = out.message;
      step.state = out.ok ? StepStatus.done : StepStatus.failed;
      if (out.ok) {
        anyDone = true;
        final pkg = step.action.args['package'];
        if (step.action.kind == ActionKind.openApp && pkg is String) {
          store?.recordLaunch(pkg);
          onLaunch?.call(pkg);
        }
        if (i < run.steps.length - 1 && stepDelay > Duration.zero) {
          await Future<void>.delayed(stepDelay);
        }
      } else {
        failed = true;
      }
      run.touch();
    }

    if (cancelled) {
      run.status = RunStatus.cancelled;
      run.summary = anyDone ? 'Stopped. Earlier steps already ran.' : 'Cancelled.';
    } else if (failed) {
      run.status = RunStatus.failed;
      final bad = run.steps.firstWhere((s) => s.state == StepStatus.failed);
      run.summary = 'Couldn\u0027t finish: ${bad.message}';
    } else {
      run.status = RunStatus.completed;
      run.summary = run.steps.map((s) => s.message).where((m) => m.isNotEmpty).join(' ');
    }
    store?.addCommand(
      userText ?? title,
      plan,
      switch (run.status) {
        RunStatus.completed => 'ok',
        RunStatus.failed => 'failed',
        _ => 'cancelled',
      },
      run.summary,
    );
    run.touch();
    return run;
  }
}

/// Validates a model-proposed intent (JSON) against the typed registry.
/// The model can only name a [ActionKind] + typed args; anything else is
/// rejected. Returns null when invalid.
List<OrbitAction>? planFromLlmJson(Object? decoded) {
  final list = decoded is Map ? decoded['actions'] : decoded;
  if (list is! List || list.isEmpty || list.length > 6) return null;
  final out = <OrbitAction>[];
  for (final item in list) {
    final a = OrbitAction.fromJson(item);
    if (a == null) return null;
    out.add(a);
  }
  return out;
}
