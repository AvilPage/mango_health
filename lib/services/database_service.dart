import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/daily_step.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  Future<Database> get database async {
    final database = _database;
    if (database != null) {
      return database;
    }

    final path = p.join(await getDatabasesPath(), 'mango_health.db');
    _database = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE daily_steps(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL UNIQUE,
            steps INTEGER NOT NULL,
            reward_points INTEGER NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE user_profile(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS user_profile(
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }
      },
    );

    return _database!;
  }

  Future<void> upsertSteps(String date, int steps, int points) async {
    final db = await database;
    final existing = await getStepsForDate(date);

    await db.insert(
      'daily_steps',
      DailyStep(
        date: date,
        steps: steps,
        rewardPoints: points,
        synced: existing?.synced ?? false,
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DailyStep>> getStepsHistory() async {
    final db = await database;
    final records = await db.query('daily_steps', orderBy: 'date DESC');
    return records.map(DailyStep.fromMap).toList();
  }

  Future<DailyStep?> getStepsForDate(String date) async {
    final db = await database;
    final result = await db.query(
      'daily_steps',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return DailyStep.fromMap(result.first);
  }

  Future<Map<String, String>> getProfile() async {
    final db = await database;
    final rows = await db.query('user_profile');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  Future<void> saveProfile(Map<String, String> fields) async {
    final db = await database;
    final batch = db.batch();
    for (final entry in fields.entries) {
      batch.insert(
        'user_profile',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> markSynced(String date) async {
    final db = await database;
    await db.update(
      'daily_steps',
      {'synced': 1},
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  Future<void> saveAuth({required String token, required String recordJson}) async {
    final db = await database;
    final batch = db.batch();
    batch.insert('user_profile', {'key': '_pb_token', 'value': token},
        conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('user_profile', {'key': '_pb_record', 'value': recordJson},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await batch.commit(noResult: true);
  }

  Future<({String token, String recordJson})?> loadAuth() async {
    final db = await database;
    final rows = await db.query(
      'user_profile',
      where: "key IN ('_pb_token', '_pb_record')",
    );
    final map = {for (final r in rows) r['key'] as String: r['value'] as String};
    final token = map['_pb_token'];
    final recordJson = map['_pb_record'];
    if (token == null || token.isEmpty || recordJson == null) return null;
    return (token: token, recordJson: recordJson);
  }

  Future<void> clearAuth() async {
    final db = await database;
    await db.delete(
      'user_profile',
      where: "key IN ('_pb_token', '_pb_record')",
    );
  }
}
