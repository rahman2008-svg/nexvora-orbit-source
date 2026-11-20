import 'app_index.dart';
import 'orbit_native.dart';

/// Every action ORBIT can execute is one of these typed kinds. The language
/// model can only *select* a kind and fill typed arguments; arguments are
/// validated here, and nothing outside this list (no shell, no code, no
/// arbitrary intents) can ever run.
enum ActionKind {
  openApp,
  openSettings,
  openCamera,
  openMap,
  setTimer,
  setAlarm,
  dial,
  openWeb,
  webSearch,
}

enum ActionRisk { safe, confirm }

const Set<String> kSettingsPages = {
  'wifi', 'bluetooth', 'display', 'sound', 'location', 'battery', 'airplane',
  'apps', 'storage', 'accessibility', 'date', 'language', 'settings',
};

class OrbitAction {
  const OrbitAction(this.kind, [this.args = const {}]);

  final ActionKind kind;
  final Map<String, Object?> args;

  static OrbitAction openApp(String package, {String? label}) =>
      OrbitAction(ActionKind.openApp, {'package': package, if (label != null) 'label': label});
  static OrbitAction settings(String page) => OrbitAction(ActionKind.openSettings, {'page': page});
  static const OrbitAction camera = OrbitAction(ActionKind.openCamera);
  static OrbitAction map([String? query]) =>
      OrbitAction(ActionKind.openMap, {if (query != null && query.isNotEmpty) 'query': query});
  static OrbitAction timer(int seconds, {String? label}) =>
      OrbitAction(ActionKind.setTimer, {'seconds': seconds, if (label != null) 'label': label});
  static OrbitAction alarm(int hour, int minute, {String? label}) =>
      OrbitAction(ActionKind.setAlarm, {'hour': hour, 'minute': minute, if (label != null) 'label': label});
  static OrbitAction dial(String number) => OrbitAction(ActionKind.dial, {'number': number});
  static OrbitAction web(String url) => OrbitAction(ActionKind.openWeb, {'url': url});
  static OrbitAction search(String query) => OrbitAction(ActionKind.webSearch, {'query': query});

  /// Sensitive actions need an explicit user confirmation before they run.
  ActionRisk get risk => switch (kind) {
        ActionKind.dial || ActionKind.openWeb || ActionKind.webSearch => ActionRisk.confirm,
        _ => ActionRisk.safe,
      };

  String get title {
    switch (kind) {
      case ActionKind.openApp:
        return 'Open ${args['label'] ?? args['package']}';
      case ActionKind.openSettings:
        return 'Open ${args['page']} settings';
      case ActionKind.openCamera:
        return 'Open camera';
      case ActionKind.openMap:
        return args['query'] == null ? 'Open maps' : 'Show "${args['query']}" on a map';
      case ActionKind.setTimer:
        return 'Start ${_fmtSeconds((args['seconds'] as num?)?.toInt() ?? 0)} timer';
      case ActionKind.setAlarm:
        final h = (args['hour'] as num?)?.toInt() ?? 0, m = (args['minute'] as num?)?.toInt() ?? 0;
        return 'Set alarm for ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      case ActionKind.dial:
        return 'Open dialer with ${args['number']}';
      case ActionKind.openWeb:
        return 'Open ${args['url']}';
      case ActionKind.webSearch:
        return 'Search the web for "${args['query']}"';
    }
  }

  /// Returns an error string when the arguments are invalid, else null.
  String? validate() {
    switch (kind) {
      case ActionKind.openApp:
        final p = args['package'];
        if (p is! String || !RegExp(r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$').hasMatch(p)) {
          return 'Invalid app package.';
        }
        return null;
      case ActionKind.openSettings:
        return kSettingsPages.contains(args['page']) ? null : 'Unsupported settings page.';
      case ActionKind.openCamera:
        return null;
      case ActionKind.openMap:
        final q = args['query'];
        return (q == null || (q is String && q.length <= 200)) ? null : 'Invalid map query.';
      case ActionKind.setTimer:
        final s = args['seconds'];
        return (s is num && s >= 1 && s <= 86400) ? null : 'Timer must be 1 second to 24 hours.';
      case ActionKind.setAlarm:
        final h = args['hour'], m = args['minute'];
        return (h is num && m is num && h >= 0 && h <= 23 && m >= 0 && m <= 59) ? null : 'Invalid alarm time.';
      case ActionKind.dial:
        final n = args['number'];
        return (n is String && RegExp(r'^[0-9+*#\s\-()]{3,20}$').hasMatch(n)) ? null : 'Invalid phone number.';
      case ActionKind.openWeb:
        final u = args['url'];
        if (u is! String) return 'Invalid link.';
        final uri = Uri.tryParse(u);
        return (uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty)
            ? null
            : 'Only http(s) links can be opened.';
      case ActionKind.webSearch:
        final q = args['query'];
        return (q is String && q.trim().isNotEmpty && q.length <= 200) ? null : 'Nothing to search for.';
    }
  }

  Map<String, Object?> toJson() => {'kind': kind.name, 'args': args};

  static OrbitAction? fromJson(Object? j) {
    if (j is! Map) return null;
    final k = ActionKind.values.where((e) => e.name == j['kind']).toList();
    if (k.isEmpty) return null;
    final a = OrbitAction(k.first, Map<String, Object?>.from((j['args'] as Map?) ?? const {}));
    return a.validate() == null ? a : null;
  }
}

String _fmtSeconds(int s) {
  if (s % 3600 == 0 && s >= 3600) return '${s ~/ 3600} h';
  if (s % 60 == 0 && s >= 60) return '${s ~/ 60} min';
  if (s > 60) return '${s ~/ 60} min ${s % 60} s';
  return '$s s';
}

/// Runs validated actions through [NativeBridge].
abstract class ActionRunner {
  Future<ActionOutcome> run(OrbitAction action);
}

class NativeActionRunner implements ActionRunner {
  NativeActionRunner(this.native, this.index);
  final NativeBridge native;
  final AppIndex index;

  @override
  Future<ActionOutcome> run(OrbitAction a) async {
    final err = a.validate();
    if (err != null) return ActionOutcome(false, 'invalid', err);
    switch (a.kind) {
      case ActionKind.openApp:
        return native.launchApp(a.args['package'] as String);
      case ActionKind.openSettings:
        return native.perform('settings', {'page': a.args['page']});
      case ActionKind.openCamera:
        return native.perform('camera', const {});
      case ActionKind.openMap:
        return native.perform('map', a.args);
      case ActionKind.setTimer:
        return native.perform('timer', a.args);
      case ActionKind.setAlarm:
        return native.perform('alarm', a.args);
      case ActionKind.dial:
        return native.perform('dial', a.args);
      case ActionKind.openWeb:
        return native.perform('web', a.args);
      case ActionKind.webSearch:
        return native.perform('web_search', a.args);
    }
  }
}
