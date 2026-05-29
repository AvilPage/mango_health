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
