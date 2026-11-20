import 'dart:typed_data';

import 'package:flutter/services.dart';

/// One launchable app as reported by Android's PackageManager.
class InstalledApp {
  InstalledApp({
    required this.package,
    required this.label,
    this.activities = const [],
    this.system = false,
    this.category = 'undefined',
    this.versionName,
    this.installTime,
    this.updateTime,
    this.intents = const [],
  });

  final String package;
  final String label;
  final List<String> activities;
  final bool system;
  final String category;
  final String? versionName;
  final int? installTime;
  final int? updateTime;

  /// Probe-intent ids this app resolves (see [AppIndex.describe]); filled by
  /// the index. Detected from public intent filters, not from private APIs.
  List<String> intents;

  factory InstalledApp.fromMap(Map<Object?, Object?> m) => InstalledApp(
        package: m['package'] as String,
        label: (m['label'] as String?) ?? (m['package'] as String),
        activities:
            ((m['activities'] as List?) ?? const []).cast<String>().toList(),
        system: (m['system'] as bool?) ?? false,
        category: (m['category'] as String?) ?? 'undefined',
        versionName: m['versionName'] as String?,
        installTime: (m['installTime'] as num?)?.toInt(),
        updateTime: (m['updateTime'] as num?)?.toInt(),
      );
}

/// Result of a native action. [ok] means Android accepted the request
/// ("asked the Clock app to…"), never that the downstream app finished it.
class ActionOutcome {
  const ActionOutcome(this.ok, this.code, this.message);
  final bool ok;
  final String code;
  final String message;

  factory ActionOutcome.fromMap(Map<Object?, Object?> m) => ActionOutcome(
      (m['ok'] as bool?) ?? false,
      (m['code'] as String?) ?? 'unknown',
      (m['message'] as String?) ?? '');
}

/// Abstraction over the native layer so the action engine is unit-testable.
abstract class NativeBridge {
  Future<List<InstalledApp>> listApps();
  Future<Uint8List?> iconFor(String package, {int size = 96});
  Future<ActionOutcome> launchApp(String package);
  Future<List<String>> supportedIntents(String package);
  Future<List<({String package, String label})>> findHandlers(String kind);
  Future<ActionOutcome> perform(String kind, Map<String, Object?> args);
  Future<Map<String, Object?>> deviceInfo();
}

/// Real implementation backed by the `orbit/apps` MethodChannel
/// (OrbitAppControl.kt).
class OrbitNative implements NativeBridge {
  OrbitNative._();
  static final OrbitNative instance = OrbitNative._();
  static const MethodChannel _ch = MethodChannel('orbit/apps');
  final Map<String, Uint8List?> _icons = {};

  @override
  Future<List<InstalledApp>> listApps() async {
    final raw = await _ch.invokeListMethod<Map<Object?, Object?>>('listApps');
    return (raw ?? const []).map(InstalledApp.fromMap).toList();
  }

  @override
  Future<Uint8List?> iconFor(String package, {int size = 96}) async {
    if (_icons.containsKey(package)) return _icons[package];
    try {
      final b = await _ch
          .invokeMethod<Uint8List>('getIcon', {'package': package, 'size': size});
      _icons[package] = b;
      return b;
    } on PlatformException {
      _icons[package] = null;
      return null;
    }
  }

  @override
  Future<ActionOutcome> launchApp(String package) => _outcome(
      () => _ch.invokeMapMethod<Object?, Object?>('launchApp', {'package': package}));

  @override
  Future<List<String>> supportedIntents(String package) async {
    final r = await _ch
        .invokeListMethod<String>('supportedIntents', {'package': package});
    return r ?? const [];
  }

  @override
  Future<List<({String package, String label})>> findHandlers(String kind) async {
    final r = await _ch.invokeListMethod<Map<Object?, Object?>>(
        'findHandlers', {'kind': kind});
    return (r ?? const [])
        .map((m) => (package: m['package'] as String, label: m['label'] as String))
        .toList();
  }

  @override
  Future<ActionOutcome> perform(String kind, Map<String, Object?> args) =>
      _outcome(() => _ch.invokeMapMethod<Object?, Object?>(
          'perform', {'kind': kind, 'args': args}));

  @override
  Future<Map<String, Object?>> deviceInfo() async {
    final r = await _ch.invokeMapMethod<String, Object?>('deviceInfo');
    return r ?? const {};
  }

  Future<ActionOutcome> _outcome(
      Future<Map<Object?, Object?>?> Function() call) async {
    try {
      final m = await call();
      if (m == null) return const ActionOutcome(false, 'no_result', 'No response from Android.');
      return ActionOutcome.fromMap(m);
    } on PlatformException catch (e) {
      return ActionOutcome(false, e.code, e.message ?? 'Native error');
    } on MissingPluginException {
      return const ActionOutcome(
          false, 'unavailable', 'App control is only available on Android.');
    }
  }
}
