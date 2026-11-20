import 'orbit_native.dart';

class ScoredApp {
  ScoredApp(this.app, this.score, this.why);
  final InstalledApp app;
  final double score;
  final String why;
}

/// Human description of probe intents (what Android says the app can handle).
const Map<String, String> kIntentLabels = {
  'view_pdf': 'open PDFs',
  'view_web': 'open web links',
  'view_image': 'view images',
  'play_audio': 'play audio',
  'play_video': 'play video',
  'share_text': 'receive shared text',
  'share_image': 'receive shared images',
  'dial': 'dial numbers',
  'compose_email': 'write email',
  'compose_sms': 'write messages',
  'map_geo': 'show map locations',
  'set_timer': 'set timers',
  'set_alarm': 'set alarms',
  'camera': 'open the camera',
  'web_search': 'web search',
  'edit_text': 'edit text',
};

/// Concept words -> (categories, probe intents, label keywords). This is
/// lexical/capability matching, NOT neural embeddings.
class _Concept {
  const _Concept(this.words, {this.categories = const [], this.intents = const [], this.labels = const []});
  final List<String> words;
  final List<String> categories;
  final List<String> intents;
  final List<String> labels;
}

const List<_Concept> _concepts = [
  _Concept(['music', 'song', 'songs', 'listen', 'audio', 'podcast', 'player', 'গান', 'মিউজিক'],
      categories: ['audio'], intents: ['play_audio'], labels: ['music', 'spotify', 'player', 'podcast', 'audio']),
  _Concept(['pdf', 'read', 'reader', 'document', 'documents', 'ebook', 'book', 'books'],
      intents: ['view_pdf'], labels: ['pdf', 'reader', 'docs', 'books', 'office']),
  _Concept(['photo', 'photos', 'picture', 'pictures', 'gallery', 'image', 'images'],
      categories: ['image'], intents: ['view_image'], labels: ['gallery', 'photos', 'camera']),
  _Concept(['camera', 'selfie', 'ক্যামেরা'], intents: ['camera'], labels: ['camera']),
  _Concept(['video', 'videos', 'movie', 'movies', 'watch', 'stream'],
      categories: ['video'], intents: ['play_video'], labels: ['video', 'youtube', 'player', 'tv']),
  _Concept(['note', 'notes', 'memo', 'write', 'notepad', 'text'],
      intents: ['edit_text'], labels: ['note', 'notes', 'keep', 'memo', 'editor']),
  _Concept(['web', 'browse', 'browser', 'internet', 'website'],
      intents: ['view_web'], labels: ['chrome', 'browser', 'firefox', 'brave', 'edge']),
  _Concept(['map', 'maps', 'navigate', 'navigation', 'directions', 'gps'],
      categories: ['maps'], intents: ['map_geo'], labels: ['maps', 'navigation', 'gps']),
  _Concept(['timer', 'alarm', 'clock', 'stopwatch'],
      intents: ['set_timer', 'set_alarm'], labels: ['clock', 'timer', 'alarm']),
  _Concept(['mail', 'email', 'gmail', 'inbox'], intents: ['compose_email'], labels: ['mail', 'gmail', 'outlook']),
  _Concept(['message', 'messages', 'sms', 'chat', 'text'],
      categories: ['social'], intents: ['compose_sms'], labels: ['messages', 'messenger', 'whatsapp', 'telegram', 'signal']),
  _Concept(['call', 'phone', 'dialer', 'dial', 'contacts'], intents: ['dial'], labels: ['phone', 'dialer', 'contacts']),
  _Concept(['calculator', 'calc', 'math', 'calculate'], labels: ['calculator', 'calc']),
  _Concept(['file', 'files', 'storage', 'folder', 'manager'], labels: ['files', 'file manager', 'explorer']),
];

/// Local index of installed, launchable apps with capability probing and
/// search. Nothing here leaves the device.
class AppIndex {
  AppIndex(this.native);
  final NativeBridge native;

  List<InstalledApp> apps = [];
  DateTime? refreshedAt;

  Future<void> refresh({bool probeIntents = true}) async {
    apps = await native.listApps();
    if (probeIntents) {
      // Probing is cheap (one PackageManager query per probe), done per app.
      for (final a in apps) {
        try {
          a.intents = await native.supportedIntents(a.package);
        } catch (_) {
          a.intents = const [];
        }
      }
    }
    refreshedAt = DateTime.now();
  }

  /// Replaces the app list directly (tests).
  void setApps(List<InstalledApp> list) {
    apps = list;
    refreshedAt = DateTime.now();
  }

  static List<String> _tokens(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s\-]', unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  /// "Can: open PDFs, play audio" – derived only from detected intent filters
  /// and Android's declared app category. Apps are NOT assumed to expose
  /// internal features.
  String describe(InstalledApp a) {
    final caps = a.intents.map((i) => kIntentLabels[i]).whereType<String>().toList();
    final cat = a.category == 'undefined' ? null : a.category;
    final parts = <String>[
      if (cat != null) 'Category: $cat',
      if (caps.isNotEmpty) 'Can ${caps.join(', ')}' else 'Can be opened',
    ];
    return parts.join(' · ');
  }

  InstalledApp? byPackage(String pkg) {
    for (final a in apps) {
      if (a.package == pkg) return a;
    }
    return null;
  }

  /// Name lookup used by "open X": strongest label matches first.
  List<ScoredApp> findByName(String name) {
    final q = name.toLowerCase().trim();
    if (q.isEmpty) return const [];
    final qt = _tokens(q);
    final out = <ScoredApp>[];
    for (final a in apps) {
      final l = a.label.toLowerCase();
      double s = 0;
      String why = '';
      if (l == q) {
        s = 100;
        why = 'exact name';
      } else if (l.startsWith(q)) {
        s = 80;
        why = 'name starts with';
      } else if (l.contains(q)) {
        s = 60;
        why = 'name contains';
      } else if (qt.isNotEmpty && qt.every((t) => l.contains(t))) {
        s = 50;
        why = 'all words in name';
      } else if (a.package.toLowerCase().contains(q.replaceAll(' ', ''))) {
        s = 35;
        why = 'package name';
      }
      if (s > 0) out.add(ScoredApp(a, s, why));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  /// Capability / semantic-ish search: expands query words through the concept
  /// table, then scores label, package, category and detected intents.
  List<ScoredApp> search(String query, {String? category, int limit = 50}) {
    final qt = _tokens(query);
    final pool = category == null || category == 'all'
        ? apps
        : apps.where((a) => _inCategory(a, category)).toList();
    if (qt.isEmpty) return pool.map((a) => ScoredApp(a, 0, '')).take(limit).toList();

    final matched = _concepts.where((c) => c.words.any(qt.contains)).toList();
    final out = <ScoredApp>[];
    for (final a in pool) {
      final l = a.label.toLowerCase();
      final pkg = a.package.toLowerCase();
      double s = 0;
      final why = <String>[];
      for (final t in qt) {
        if (l == t) {
          s += 100;
          why.add('name');
        } else if (l.startsWith(t)) {
          s += 70;
          why.add('name');
        } else if (l.contains(t)) {
          s += 50;
          why.add('name');
        } else if (pkg.contains(t)) {
          s += 25;
          why.add('package');
        }
      }
      for (final c in matched) {
        if (c.categories.contains(a.category)) {
          s += 35;
          why.add('category ${a.category}');
        }
        final hit = c.intents.where(a.intents.contains).toList();
        if (hit.isNotEmpty) {
          s += 40;
          why.add(hit.map((h) => kIntentLabels[h] ?? h).join('/'));
        }
        if (c.labels.any((w) => l.contains(w))) {
          s += 30;
          why.add('known app type');
        }
      }
      if (s > 0) out.add(ScoredApp(a, s, why.toSet().join(', ')));
    }
    out.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.app.label.toLowerCase().compareTo(b.app.label.toLowerCase());
    });
    return out.take(limit).toList();
  }

  static const List<String> categoryTabs = ['all', 'media', 'productivity', 'tools', 'social'];

  bool _inCategory(InstalledApp a, String tab) {
    switch (tab) {
      case 'media':
        return {'audio', 'video', 'image'}.contains(a.category) ||
            a.intents.any((i) => {'play_audio', 'play_video', 'view_image'}.contains(i));
      case 'productivity':
        return a.category == 'productivity' ||
            a.intents.any((i) => {'view_pdf', 'edit_text', 'compose_email'}.contains(i));
      case 'social':
        return a.category == 'social' || a.intents.contains('compose_sms');
      case 'tools':
        return a.intents.any((i) => {'set_timer', 'set_alarm', 'camera', 'dial', 'map_geo'}.contains(i)) ||
            (a.system && a.category == 'undefined');
      default:
        return true;
    }
  }
}
