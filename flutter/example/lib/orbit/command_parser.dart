import 'action_registry.dart';
import 'app_index.dart';
import 'orbit_native.dart';

/// What the parser decided for one user utterance.
class ParseResult {
  ParseResult.plan(this.plan)
      : question = null,
        choices = const [],
        notFound = null;
  ParseResult.ask(this.question, this.choices)
      : plan = const [],
        notFound = null;
  ParseResult.missing(this.notFound)
      : plan = const [],
        question = null,
        choices = const [];

  final List<OrbitAction> plan;

  /// Set when several apps match and the user must pick one.
  final String? question;
  final List<InstalledApp> choices;

  /// Set when the utterance was an app request but nothing matched.
  final String? notFound;
}

/// Deterministic, fast first stage of the action pipeline (English + a few
/// Bangla verbs). It only ever produces typed [OrbitAction]s or asks a
/// question. Anything it does not recognise returns null so the request falls
/// through to the chat (and, optionally, to the LLM-intent stage in
/// [planFromLlmJson]).
class CommandParser {
  CommandParser(this.index);
  final AppIndex index;

  static const Map<String, String> _settingsWords = {
    'wifi': 'wifi', 'wi-fi': 'wifi', 'wi fi': 'wifi', 'ওয়াইফাই': 'wifi', 'ওয়াই-ফাই': 'wifi',
    'bluetooth': 'bluetooth', 'ব্লুটুথ': 'bluetooth',
    'display': 'display', 'brightness': 'display', 'screen': 'display',
    'sound': 'sound', 'volume': 'sound', 'audio': 'sound',
    'location': 'location', 'gps': 'location',
    'battery': 'battery', 'airplane': 'airplane', 'flight mode': 'airplane',
    'storage': 'storage', 'accessibility': 'accessibility',
    'date': 'date', 'time': 'date', 'language': 'language',
    'apps': 'apps',
  };

  static final RegExp _open = RegExp(
      r'^(?:open|launch|start|run|show|go to|খুলো|খোলো|খুলুন|চালু করো)\s+(?:up\s+)?(?:the\s+|my\s+)?(.+)$');

  static String _clean(String t) {
    var s = t.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[!?.]+$'), '').trim();
    s = s.replaceFirst(RegExp(r'^(?:hey |ok |okay )?orbit[, ]+'), '');
    s = s.replaceFirst(RegExp(r'^(?:please|can you|could you|would you|i want to|i need to|i\u0027d like to)\s+'), '');
    s = s.replaceFirst(RegExp(r'^please\s+'), '');
    s = s.replaceFirst(RegExp(r'\s+please$'), '');
    return s.trim();
  }

  /// Splits "A and then B", "A, then B", "A then B".
  static List<String> _split(String s) =>
      s.split(RegExp(r'\s*(?:,\s*)?(?:and then|then|and also|after that)\s+')).where((p) => p.trim().isNotEmpty).toList();

  ParseResult? parse(String text) {
    final cleaned = _clean(text);
    if (cleaned.isEmpty) return null;
    // Existing chat handlers own these (reminders, music playback, radio).
    if (RegExp(r'\bremind(er)?\b').hasMatch(cleaned)) return null;
    if (RegExp(r'^play\b').hasMatch(cleaned)) return null;

    final parts = _split(cleaned);
    if (parts.length > 1) {
      final plan = <OrbitAction>[];
      for (final p in parts) {
        final r = _parseOne(p);
        if (r == null || r.plan.isEmpty) return null; // only run fully-understood plans
        plan.addAll(r.plan);
      }
      return ParseResult.plan(plan);
    }
    return _parseOne(cleaned);
  }

  ParseResult? _parseOne(String s) {
    // Timer: "start a 30 minute timer", "set a timer for 5 minutes", "timer 10 min".
    final secs = _parseTimer(s);
    if (secs != null) return ParseResult.plan([OrbitAction.timer(secs)]);

    final alarm = _parseAlarm(s);
    if (alarm != null) return ParseResult.plan([OrbitAction.alarm(alarm.$1, alarm.$2)]);

    // Dial: "call 01712345678" / "dial 999". Opens the dialer only.
    final dial = RegExp(r'^(?:call|dial|ring)\s+([+0-9][0-9\s\-]{2,19})$').firstMatch(s);
    if (dial != null) return ParseResult.plan([OrbitAction.dial(dial.group(1)!.trim())]);

    // Web search.
    final web = RegExp(r'^(?:search (?:the )?(?:web|internet|google) for|google|web search)\s+(.+)$').firstMatch(s);
    if (web != null) return ParseResult.plan([OrbitAction.search(web.group(1)!.trim())]);

    // "find (me)? an app for X" / "find my music app" / "which app can X"
    final find = RegExp(
            r'^(?:find|search for|look for|show|which|what)\s+(?:me\s+)?(?:an?\s+|the\s+|my\s+)?(?:app(?:lication)?s?\s+(?:for|to|that can|which can)\s+(.+)|(.+?)\s+app(?:lication)?s?)$')
        .firstMatch(s);
    if (find != null) {
      final cap = (find.group(1) ?? find.group(2) ?? '').trim();
      if (cap.isNotEmpty) return _choose(cap, capability: true);
    }

    // Camera shortcuts.
    if (RegExp(r'^(?:open|launch|start)?\s*(?:the\s+)?camera$|^take (?:a )?(?:photo|picture|selfie)$|^ক্যামেরা').hasMatch(s)) {
      return ParseResult.plan([OrbitAction.camera]);
    }

    final m = _open.firstMatch(s);
    if (m == null) return null;
    var target = m.group(1)!.trim();
    target = target.replaceFirst(RegExp(r'\s+(?:app|application)$'), '').trim();

    // Settings: "open wifi settings", "bluetooth settings".
    final st = RegExp(r'^(.+?)\s+settings?$').firstMatch(target);
    if (st != null) {
      final page = _settingsWords[st.group(1)!.trim()];
      if (page != null) return ParseResult.plan([OrbitAction.settings(page)]);
    }
    if (target == 'settings' || target == 'phone settings' || target == 'system settings') {
      return ParseResult.plan([OrbitAction.settings('settings')]);
    }
    if (_settingsWords.containsKey(target) && (target.contains('wi') || target == 'bluetooth' || target == 'ওয়াইফাই' || target == 'ব্লুটুথ')) {
      return ParseResult.plan([OrbitAction.settings(_settingsWords[target]!)]);
    }

    // "open maps" / "open map of X"
    final mp = RegExp(r'^maps?(?:\s+(?:for|of|to)\s+(.+))?$').firstMatch(target);
    if (mp != null) return ParseResult.plan([OrbitAction.map(mp.group(1))]);

    // "open my music app" – a category/capability word, not a name.
    final generic = RegExp(r'^(music|video|photo|photos|pdf|notes?|note|browser|email|mail)(?:\s+(?:player|reader|app|application))?$').firstMatch(target);
    if (generic != null && index.findByName(target).isEmpty) {
      return _choose(generic.group(1)!, capability: true);
    }

    return _choose(target, capability: false);
  }

  ParseResult _choose(String query, {required bool capability}) {
    if (!capability) {
      final named = index.findByName(query);
      if (named.isNotEmpty) {
        final top = named.first;
        final strong = named.where((n) => n.score >= top.score - 10).toList();
        if (strong.length == 1 || top.score >= 100) {
          return ParseResult.plan([OrbitAction.openApp(top.app.package, label: top.app.label)]);
        }
        return ParseResult.ask('I found ${strong.length} apps matching "$query". Which one?',
            strong.map((e) => e.app).take(6).toList());
      }
    }
    final hits = index.search(query).where((h) => h.score >= 30).toList();
    if (hits.isEmpty) {
      return ParseResult.missing('I couldn\u0027t find an installed app for "$query".');
    }
    final apps = hits.map((h) => h.app).take(6).toList();
    if (apps.length == 1) {
      return ParseResult.ask('I found 1 compatible app. Open it?', apps);
    }
    return ParseResult.ask('I found ${apps.length} compatible apps. Which one do you want to open?', apps);
  }

  static int? _parseTimer(String s) {
    if (!RegExp(r'\btimer\b').hasMatch(s) && !RegExp(r'^(?:countdown)').hasMatch(s)) return null;
    final m = RegExp(r'(\d+(?:\.\d+)?)\s*(seconds?|secs?|s|minutes?|mins?|m|hours?|hrs?|h)\b').firstMatch(s);
    if (m == null) return null;
    final n = double.parse(m.group(1)!);
    final u = m.group(2)!;
    final mult = u.startsWith('h') ? 3600 : (u.startsWith('m') ? 60 : 1);
    final secs = (n * mult).round();
    return (secs >= 1 && secs <= 86400) ? secs : null;
  }

  static (int, int)? _parseAlarm(String s) {
    if (!RegExp(r'\balarm\b').hasMatch(s)) return null;
    final m = RegExp(r'(?:at|for)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?').firstMatch(s);
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final min = int.tryParse(m.group(2) ?? '0') ?? 0;
    final ap = m.group(3);
    if (ap == 'pm' && h < 12) h += 12;
    if (ap == 'am' && h == 12) h = 0;
    if (h > 23 || min > 59) return null;
    return (h, min);
  }
}
