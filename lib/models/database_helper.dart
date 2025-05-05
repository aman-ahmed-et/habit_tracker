import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('habits.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);
      return await openDatabase(path, version: 1, onCreate: _createDB);
    } catch (e) {
      debugPrint('Error initializing database: $e');
      rethrow;
    }
  }

  Future _createDB(Database db, int version) async {
    try {
      await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        frequency TEXT NOT NULL,
        stage INTEGER NOT NULL,
        health INTEGER NOT NULL,
        revive_count INTEGER NOT NULL,
        last_updated TEXT NOT NULL
      )
      ''');
      await db.execute('''
      CREATE TABLE progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        progress INTEGER DEFAULT 1,
        date TEXT NOT NULL,
        FOREIGN KEY (habit_id) REFERENCES habits (id)
      )
      ''');
      debugPrint('Database created with habits and progress tables');
    } catch (e) {
      debugPrint('Error creating database: $e');
      rethrow;
    }
  }

  Future<void> insertHabit(Map<String, dynamic> habit) async {
    final db = await database;
    try {
      habit['last_updated'] = DateTime.now().toIso8601String();
      await db.insert('habits', habit);
      debugPrint('Inserted habit: ${habit['name']}');
    } catch (e) {
      debugPrint('Error inserting habit: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getHabits() async {
    final db = await database;
    try {
      final habits = await db.query('habits');
      debugPrint('Retrieved ${habits.length} habits');
      return habits;
    } catch (e) {
      debugPrint('Error retrieving habits: $e');
      return [];
    }
  }

  Future<void> deleteHabit(int habitId) async {
    final db = await database;
    try {
      await db.delete('progress', where: 'habit_id = ?', whereArgs: [habitId]);
      await db.delete('habits', where: 'id = ?', whereArgs: [habitId]);
      debugPrint('Deleted habit and its progress entries: $habitId');
    } catch (e) { 
      debugPrint('Error deleting habits: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getProgress(int habitId) async {
    final db = await database;
    try {
      final progress = await db.query(
        'progress',
        where: 'habit_id = ?',
        whereArgs: [habitId],
        orderBy: 'date DESC',
      );
      debugPrint('Retrieved ${progress.length} progress entries for habit $habitId');
      return progress;
    } catch (e) {
      debugPrint('Error retrieving progress: $e');
      return [];
    }
  }

  Future<void> insertProgress(Map<String, dynamic> progress) async {
    final db = await database;
    try {
      await db.insert('progress', progress);
      debugPrint('Inserted progress for habit ${progress['habit_id']}: ${progress['progress']} on ${progress['date']}');
    } catch (e) {
      debugPrint('Error inserting progress: $e');
      rethrow;
    }
  }

  Future<void> deleteProgressByDate(int habitId, String date) async {
    final db = await database;
    try {
      await db.delete(
        'progress',
        where: 'habit_id = ? AND date LIKE ?',
        whereArgs: [habitId, '$date%'],
      );
      debugPrint('Deleted progress for habit $habitId on date $date');
    } catch (e) {
      debugPrint('Error deleting progress: $e');
      rethrow;
    }
  }

  Future<void> updateHabitTree(int id, int stage, int health, int reviveCount, { required String lastUpdated}) async {
    final db = await database;
    try {
      await db.update(
        'habits',
        {'stage': stage, 'health': health, 'revive_count': reviveCount, 'last_updated': lastUpdated},
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('Updated tree for habit id $id: stage=$stage, health=$health, revives=$reviveCount, last_updated: $lastUpdated');
    } catch (e) {
      debugPrint('Error updating habit tree: $e');
      rethrow;
    }
  }
}