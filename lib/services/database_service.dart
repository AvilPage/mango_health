import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

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
      version: 1,
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
      },
    );

    return _database!;
  }

  Future<void> upsertSteps(String date, int steps, int points) async {
    final db = await database;
    final existing = await getStepsForDate(date);

    await db.insert(
      'daily_steps',
      {
        'date': date,
        'steps': steps,
        'reward_points': points,
        'synced': existing?['synced'] ?? 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> getStepsHistory() async {
    final db = await database;
    return db.query('daily_steps', orderBy: 'date DESC');
  }

  Future<Map<String, Object?>?> getStepsForDate(String date) async {
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

    return result.first;
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
}
