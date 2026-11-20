import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexvora_orbit/orbit/action_registry.dart';
import 'package:nexvora_orbit/orbit/app_index.dart';
import 'package:nexvora_orbit/orbit/command_parser.dart';
import 'package:nexvora_orbit/orbit/orbit_native.dart';
import 'package:nexvora_orbit/orbit/orbit_store.dart';
import 'package:nexvora_orbit/orbit/workflow_engine.dart';

class FakeNative implements NativeBridge {
  final List<String> calls = [];
  bool failNext = false;
  @override
  Future<List<InstalledApp>> listApps() async => [];
  @override
  Future<Uint8List?> iconFor(String package, {int size = 96}) async => null;
  @override
  Future<ActionOutcome> launchApp(String package) async {
    calls.add('launch:$package');
    return const ActionOutcome(true, 'launched', 'Asked Android to open it.');
  }

  @override
  Future<List<String>> supportedIntents(String package) async => [];
  @override
  Future<List<({String package, String label})>> findHandlers(String kind) async => [];
  @override
  Future<ActionOutcome> perform(String kind, Map<String, Object?> args) async {
    calls.add('$kind:$args');
    if (failNext) return const ActionOutcome(false, 'no_handler', 'No app can do this.');
    return ActionOutcome(true, 'launched', 'ok $kind');
  }

  @override
  Future<Map<String, Object?>> deviceInfo() async => {};
}

AppIndex _index() {
  final i = AppIndex(FakeNative());
  i.setApps([
    InstalledApp(package: 'com.google.android.youtube', label: 'YouTube', category: 'video', intents: ['play_video']),
    InstalledApp(package: 'com.spotify.music', label: 'Spotify', category: 'audio', intents: ['play_audio']),
    InstalledApp(package: 'com.example.player', label: 'Music Player', category: 'audio', intents: ['play_audio']),
    InstalledApp(package: 'com.android.calculator2', label: 'Calculator'),
    InstalledApp(package: 'com.example.pdf', label: 'PDF Reader', intents: ['view_pdf']),
  ]);
  return i;
}

void main() {
  group('OrbitAction validation', () {
    test('rejects bad args', () {
      expect(OrbitAction.timer(0).validate(), isNotNull);
      expect(OrbitAction.timer(90000).validate(), isNotNull);
      expect(OrbitAction.timer(60).validate(), isNull);
      expect(OrbitAction.web('file:///etc/passwd').validate(), isNotNull);
      expect(OrbitAction.web('https://example.com').validate(), isNull);
      expect(OrbitAction.settings('rm -rf').validate(), isNotNull);
      expect(OrbitAction.openApp('not a package').validate(), isNotNull);
      expect(OrbitAction.dial('abc').validate(), isNotNull);
    });
    test('json round trip rejects invalid', () {
      expect(OrbitAction.fromJson({'kind': 'shell', 'args': {}}), isNull);
      expect(OrbitAction.fromJson(OrbitAction.timer(30).toJson()), isNotNull);
      expect(OrbitAction.fromJson({'kind': 'setTimer', 'args': {'seconds': -1}}), isNull);
    });
    test('sensitive actions require confirmation', () {
      expect(OrbitAction.dial('999').risk, ActionRisk.confirm);
      expect(OrbitAction.camera.risk, ActionRisk.safe);
    });
    test('LLM json is validated against registry', () {
      expect(planFromLlmJson({'actions': [{'kind': 'openCamera', 'args': {}}]}), isNotNull);
      expect(planFromLlmJson({'actions': [{'kind': 'runShell', 'args': {'cmd': 'ls'}}]}), isNull);
      expect(planFromLlmJson('nonsense'), isNull);
    });
  });

  group('CommandParser', () {
    final p = CommandParser(_index());
    test('open app by name', () {
      final r = p.parse('Open YouTube')!;
      expect(r.plan.single.kind, ActionKind.openApp);
      expect(r.plan.single.args['package'], 'com.google.android.youtube');
    });
    test('timer', () {
      expect(p.parse('start a 30 minute timer')!.plan.single.args['seconds'], 1800);
      expect(p.parse('set a timer for 90 seconds')!.plan.single.args['seconds'], 90);
    });
    test('settings and camera', () {
      expect(p.parse('open wifi settings')!.plan.single.args['page'], 'wifi');
      expect(p.parse('open camera')!.plan.single.kind, ActionKind.openCamera);
    });
    test('ambiguous music app asks', () {
      final r = p.parse('open my music app')!;
      expect(r.plan, isEmpty);
      expect(r.choices.length, greaterThanOrEqualTo(2));
    });
    test('find app for PDFs', () {
      final r = p.parse('find an app for reading pdf')!;
      expect(r.choices.first.package, 'com.example.pdf');
    });
    test('multi step', () {
      final r = p.parse('open calculator and then start a 5 minute timer')!;
      expect(r.plan.length, 2);
    });
    test('unrelated chat and reminders fall through', () {
      expect(p.parse('what is the capital of France'), isNull);
      expect(p.parse('remind me to open the door in 5 minutes'), isNull);
      expect(p.parse('play some jazz'), isNull);
    });
    test('missing app', () {
      expect(p.parse('open zzzqqq')!.notFound, isNotNull);
    });
  });

  group('WorkflowEngine', () {
    test('runs steps in order and logs', () async {
      final native = FakeNative();
      final store = OrbitStore.memory();
      final engine = WorkflowEngine(
        runner: NativeActionRunner(native, _index()),
        confirm: (_) async => true,
        store: store,
        stepDelay: Duration.zero,
      );
      final run = await engine.run('t', [OrbitAction.camera, OrbitAction.timer(60)], userText: 'x');
      expect(run.status, RunStatus.completed);
      expect(native.calls.length, 2);
      expect(store.recentCommands().single.status, 'ok');
    });
    test('failure stops and skips rest, never claims success', () async {
      final native = FakeNative()..failNext = true;
      final engine = WorkflowEngine(
        runner: NativeActionRunner(native, _index()),
        confirm: (_) async => true,
        stepDelay: Duration.zero,
      );
      final run = await engine.run('t', [OrbitAction.camera, OrbitAction.timer(60)]);
      expect(run.status, RunStatus.failed);
      expect(run.steps[1].state, StepStatus.skipped);
      expect(native.calls.length, 1);
    });
    test('declined confirmation cancels', () async {
      final native = FakeNative();
      final engine = WorkflowEngine(
        runner: NativeActionRunner(native, _index()),
        confirm: (_) async => false,
        stepDelay: Duration.zero,
      );
      final run = await engine.run('t', [OrbitAction.dial('999')]);
      expect(run.status, RunStatus.cancelled);
      expect(native.calls, isEmpty);
    });
  });

  group('OrbitStore', () {
    test('favorites, workflows, clear', () {
      final s = OrbitStore.memory();
      expect(s.toggleFavorite('a.b'), isTrue);
      expect(s.favorites(), ['a.b']);
      s.saveWorkflow('w', [OrbitAction.camera]);
      expect(s.workflows().single.steps.single.kind, ActionKind.openCamera);
      s.addCommand('hi', const [], 'ok', 'm');
      s.clearAll();
      expect(s.favorites(), isEmpty);
      expect(s.workflows(), isEmpty);
      expect(s.recentCommands(), isEmpty);
    });
  });
}
