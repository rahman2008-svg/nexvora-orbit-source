import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'action_registry.dart';
import 'app_index.dart';
import 'command_parser.dart';
import 'orbit_native.dart';
import 'orbit_store.dart';
import 'workflow_engine.dart';

/// Glue object owned by the root screen: app index + parser + engine + store.
class OrbitController extends ChangeNotifier {
  OrbitController({NativeBridge? native, OrbitStore? store})
      : native = native ?? OrbitNative.instance,
        store = store {
    index = AppIndex(this.native);
    parser = CommandParser(index);
    runner = NativeActionRunner(this.native, index);
    engine = WorkflowEngine(
      runner: runner,
      confirm: (a) => confirmUi?.call(a) ?? Future.value(false),
      store: this.store,
      onLaunch: (_) => notifyListeners(),
    );
  }

  final NativeBridge native;
  OrbitStore? store;
  late final AppIndex index;
  late final CommandParser parser;
  late final NativeActionRunner runner;
  late WorkflowEngine engine;

  /// Installed by the UI: shows a confirmation dialog for sensitive actions.
  /// With no UI attached the answer is "no" (fail safe).
  Future<bool> Function(OrbitAction)? confirmUi;

  bool ready = false;
  bool indexing = false;
  String? error;
  int? totalRamBytes;

  /// Lets UI code announce a change (favorites etc.) without calling the
  /// protected [notifyListeners] directly.
  void changed() => notifyListeners();

  Future<void> init() async {
    try {
      if (store == null) {
        final dir = await getApplicationSupportDirectory();
        store = OrbitStore.open('${dir.path}${Platform.pathSeparator}orbit.sqlite');
        // Rebuild engine with the real store.
        engine = WorkflowEngine(
          runner: runner,
          confirm: (a) => confirmUi?.call(a) ?? Future.value(false),
          store: store,
          onLaunch: (_) => notifyListeners(),
        );
      }
      ready = true;
      notifyListeners();
      await refreshApps();
      try {
        final info = await native.deviceInfo();
        totalRamBytes = (info['totalRam'] as num?)?.toInt();
      } catch (_) {}
    } catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  Future<void> refreshApps() async {
    indexing = true;
    notifyListeners();
    try {
      await index.refresh();
      error = null;
    } catch (e) {
      error = 'Could not read installed apps: $e';
    }
    indexing = false;
    notifyListeners();
  }

  /// Runs [plan] through the engine and returns the finished run.
  Future<WorkflowRun> runPlan(String title, List<OrbitAction> plan, {String? userText}) async {
    final r = await engine.run(title, plan, userText: userText);
    notifyListeners();
    return r;
  }

  @override
  void dispose() {
    store?.close();
    super.dispose();
  }
}
