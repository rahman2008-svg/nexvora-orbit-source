import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'action_registry.dart';

class CommandRecord {
  CommandRecord({
    required this.id,
    required this.ts,
    required this.text,
    required this.status,
    required this.message,
    required this.plan,
  });
  final int id;
  final DateTime ts;
  final String text;
  final String status; // ok | failed | cancelled | declined | info
  final String message;
  final List<OrbitAction> plan;
}

class SavedWorkflow {
  SavedWorkflow({
    required this.id,
    required this.name,
    required this.steps,
    required this.enabled,
    required this.createdAt,
  });
  final int id;
  final String name;
  final List<OrbitAction> steps;
  final bool enabled;
  final DateTime createdAt;
}

/// Local SQLite persistence for ORBIT's command history, saved workflows,
/// favourite apps and recent launches. Never leaves the device; every table
/// can be cleared from the Activity screen.
class OrbitStore {
  OrbitStore._(this._db) {
    _migrate();
  }

  static OrbitStore open(String path) => OrbitStore._(sqlite3.open(path));
  static OrbitStore memory() => OrbitStore._(sqlite3.openInMemory());

  final Database _db;

  void _migrate() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS commands(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts INTEGER NOT NULL,
        text TEXT NOT NULL,
        status TEXT NOT NULL,
        message TEXT NOT NULL,
        plan TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS favorites(package TEXT PRIMARY KEY, ts INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS launches(id INTEGER PRIMARY KEY AUTOINCREMENT, package TEXT NOT NULL, ts INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS workflows(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        steps TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        created INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS kv(k TEXT PRIMARY KEY, v TEXT NOT NULL);
    ''');
  }

  // ── Commands ──────────────────────────────────────────────────────────────
  int addCommand(String text, List<OrbitAction> plan, String status, String message) {
    _db.execute('INSERT INTO commands(ts,text,status,message,plan) VALUES(?,?,?,?,?)', [
      DateTime.now().millisecondsSinceEpoch,
      text,
      status,
      message,
      jsonEncode(plan.map((a) => a.toJson()).toList()),
    ]);
    // Keep the log bounded.
    _db.execute('DELETE FROM commands WHERE id NOT IN (SELECT id FROM commands ORDER BY id DESC LIMIT 500)');
    return _db.lastInsertRowId;
  }

  List<CommandRecord> recentCommands({int limit = 50}) {
    final rs = _db.select('SELECT * FROM commands ORDER BY id DESC LIMIT ?', [limit]);
    return rs.map((r) {
      final raw = jsonDecode(r['plan'] as String) as List;
      return CommandRecord(
        id: r['id'] as int,
        ts: DateTime.fromMillisecondsSinceEpoch(r['ts'] as int),
        text: r['text'] as String,
        status: r['status'] as String,
        message: r['message'] as String,
        plan: raw.map(OrbitAction.fromJson).whereType<OrbitAction>().toList(),
      );
    }).toList();
  }

  void deleteCommand(int id) => _db.execute('DELETE FROM commands WHERE id=?', [id]);
  void clearCommands() => _db.execute('DELETE FROM commands');

  // ── Favourites / launches ────────────────────────────────────────────────
  bool isFavorite(String pkg) =>
      _db.select('SELECT 1 FROM favorites WHERE package=?', [pkg]).isNotEmpty;

  bool toggleFavorite(String pkg) {
    if (isFavorite(pkg)) {
      _db.execute('DELETE FROM favorites WHERE package=?', [pkg]);
      return false;
    }
    _db.execute('INSERT INTO favorites(package,ts) VALUES(?,?)', [pkg, DateTime.now().millisecondsSinceEpoch]);
    return true;
  }

  List<String> favorites() =>
      _db.select('SELECT package FROM favorites ORDER BY ts DESC').map((r) => r['package'] as String).toList();

  /// "Recently used" = apps launched THROUGH ORBIT (Android's usage-stats API
  /// needs a special-access permission that ORBIT deliberately does not ask for).
  void recordLaunch(String pkg) {
    _db.execute('INSERT INTO launches(package,ts) VALUES(?,?)', [pkg, DateTime.now().millisecondsSinceEpoch]);
    _db.execute('DELETE FROM launches WHERE id NOT IN (SELECT id FROM launches ORDER BY id DESC LIMIT 200)');
  }

  List<String> recentLaunches({int limit = 8}) => _db
      .select('SELECT package, MAX(ts) AS t FROM launches GROUP BY package ORDER BY t DESC LIMIT ?', [limit])
      .map((r) => r['package'] as String)
      .toList();

  // ── Workflows ────────────────────────────────────────────────────────────
  int saveWorkflow(String name, List<OrbitAction> steps, {bool enabled = true}) {
    _db.execute('INSERT INTO workflows(name,steps,enabled,created) VALUES(?,?,?,?)', [
      name,
      jsonEncode(steps.map((a) => a.toJson()).toList()),
      enabled ? 1 : 0,
      DateTime.now().millisecondsSinceEpoch,
    ]);
    return _db.lastInsertRowId;
  }

  List<SavedWorkflow> workflows() {
    final rs = _db.select('SELECT * FROM workflows ORDER BY id DESC');
    return rs.map((r) {
      final raw = jsonDecode(r['steps'] as String) as List;
      return SavedWorkflow(
        id: r['id'] as int,
        name: r['name'] as String,
        steps: raw.map(OrbitAction.fromJson).whereType<OrbitAction>().toList(),
        enabled: (r['enabled'] as int) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created'] as int),
      );
    }).toList();
  }

  void setWorkflowEnabled(int id, bool on) =>
      _db.execute('UPDATE workflows SET enabled=? WHERE id=?', [on ? 1 : 0, id]);
  void deleteWorkflow(int id) => _db.execute('DELETE FROM workflows WHERE id=?', [id]);

  // ── Key/value (small preferences) ────────────────────────────────────────
  String? getKv(String k) {
    final r = _db.select('SELECT v FROM kv WHERE k=?', [k]);
    return r.isEmpty ? null : r.first['v'] as String;
  }

  void setKv(String k, String v) => _db.execute('INSERT OR REPLACE INTO kv(k,v) VALUES(?,?)', [k, v]);

  // ── Memory controls ──────────────────────────────────────────────────────
  void clearWorkflows() => _db.execute('DELETE FROM workflows');
  void clearLaunchesAndFavorites() {
    _db.execute('DELETE FROM launches');
    _db.execute('DELETE FROM favorites');
  }

  /// Wipes everything ORBIT's action layer has stored.
  void clearAll() {
    clearCommands();
    clearWorkflows();
    clearLaunchesAndFavorites();
    _db.execute('DELETE FROM kv');
  }

  void close() => _db.dispose();
}
