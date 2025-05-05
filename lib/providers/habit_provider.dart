import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/database_helper.dart';

class HabitProvider with ChangeNotifier {
  List<Map<String, dynamic>> _habits = [];
  List<Map<String, dynamic>> get habits => _habits;

  HabitProvider() {
    loadHabits();
  }

  Future<void> loadHabits() async {
    try {
      _habits = await DatabaseHelper.instance.getHabits();
      debugPrint('Loaded ${_habits.length} habits in provider');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading habits: $e');
      _habits = [];
      notifyListeners();
    }
  }

  Future<void> addHabit(String name, String frequency) async {
    try {
      await DatabaseHelper.instance.insertHabit({
        'name': name,
        'frequency': frequency,
        'stage': 0,
        'health': 100,
        'revive_count': 3,
      });
      await loadHabits();
      debugPrint('Added habit: $name');
    } catch (e) {
      debugPrint('Error adding habit: $e');
    }
  }

  Future<void> addProgress(int habitId, int progress, String date) async {
    try {
      await DatabaseHelper.instance.insertProgress({
        'habit_id': habitId,
        'progress': progress,
        'date': date,
      });
      await updateHabitTreeState(habitId);
      await loadHabits();
      debugPrint('Added progress $progress for habit id $habitId on $date');
    } catch (e) {
      debugPrint('Error adding progress: $e');
    }
  }

  Future<void> removeProgressByDate(int habitId, String date) async {
    try {
      await DatabaseHelper.instance.deleteProgressByDate(habitId, date);
      await updateHabitTreeState(habitId);
      await loadHabits();
      debugPrint('Removed latest progress for habit id $habitId');
    } catch (e) {
      debugPrint('Error removing progress: $e');
    }
  }

  Future<void> deleteHabit(int habitId) async {
    try {
      await DatabaseHelper.instance.deleteHabit(habitId);
      await loadHabits();
      debugPrint('Deleted habit id $habitId');
    } catch (e) {
      debugPrint('Error deleting habit: $e');
    }
  }

  Future<void> updateHabitTreeState(int habitId) async {
    try {
      final habits = await DatabaseHelper.instance.getHabits();
      final habit = habits.firstWhere((h) => h['id'] == habitId, orElse: () => {});

      if (habit.isEmpty) {
        debugPrint('Habit id $habitId not found');
        return;
      }

      final now = DateTime.now();

      final progressEntries = await DatabaseHelper.instance.getProgress(habitId);

      String dateOnly(DateTime dt) => dt.toIso8601String().split('T')[0];
      final today = dateOnly(now);
      bool isCompleted = progressEntries.any((p) => dateOnly(DateTime.parse(p['date'])).compareTo(today) == 0);


      int stage = habit['stage'] as int;
      int health = habit['health'] as int;
      int reviveCount = habit['revive_count'] as int;

      if (isCompleted) {
        stage++;
        health = 100;
      } else if (!isCompleted) {
        health -= 50;
        if (health <= 0 && reviveCount > 0) {
          reviveCount--;
          health = 100;
        } else if (health <= 0) {
          stage = 0;
          health = 100;
          reviveCount = 3;
        }
      }

      await DatabaseHelper.instance.updateHabitTree(habitId, stage, health, reviveCount, lastUpdated: now.toIso8601String());
      debugPrint('Updated tree state for habit id $habitId');
    } catch (e) {
      debugPrint('Error updating habit tree state: $e');
    }
  }

  Future<List<String>> getProgressHistory(int habitId) async {
    try {
      final progressEntries = await DatabaseHelper.instance.getProgress(habitId);
      final dates = progressEntries
          .map((p) => p['date'].toString().split('T')[0])
          .toSet()
          .toList()
          ..sort();
      return dates;
    } catch (e) {
      debugPrint('Error getting progress history: $e');
      return [];
    }
  }

  Future<void> reviveHabit(int id) async {
    final habit = _habits.firstWhere((h) => h['id'] == id);
    int reviveCount = habit['revive_count'] as int;
    int stage = habit['stage'] as int;
    if (reviveCount > 0) {
      reviveCount--; 
    }
    else {
      reviveCount = 3; stage = 0;
    }
      await DatabaseHelper.instance.updateHabitTree(
        id,
        stage,
        100,
        reviveCount,
        lastUpdated: DateTime.now().toIso8601String(),
      );
      await loadHabits();
  }
}