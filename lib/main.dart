import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import './providers/habit_provider.dart';
import './animations/tree_animation.dart';
import './screens/add_habit_screen.dart';
import './models/database_helper.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => HabitProvider(),
        child: MaterialApp(
          title: 'Habit Tracker',
          theme: ThemeData(primarySwatch: Colors.green),
          home: HomeScreen(),
        ),
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Habit Tracker')),
      body: Consumer<HabitProvider>(
        builder: (context, habitProv, _) {
          final habits = habitProv.habits;
          if (habits.isEmpty) return Center(child: Text('No habits added yet!'));
          return ListView.builder(
            padding: EdgeInsets.all(8.0),
            itemCount: habits.length,
            itemBuilder: (context, index) {
              final habit = habits[index];
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: DatabaseHelper.instance.getProgress(habit['id']),
                builder: (context, snapshot) {
                  return Card(
                    elevation: 4,
                    margin: EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(habit['name'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text('Stage: ${habit['stage']}'),
                                    Text('Health: ${habit['health']}% | Revives Remaining: ${habit['revive_count']}'),
                                  ],
                                ),
                              ),
                              Tooltip(
                                message: 'View History',
                                child: IconButton(
                                  icon: Icon(Icons.history, color: Colors.blue),
                                  onPressed: () async {
                                    final doneDates = await habitProv.getProgressHistory(habit['id']);
                                    if (!context.mounted) return;
                                    
                                    final now = DateTime.now();
                                    final firstDay = DateTime(now.year, now.month - 3, 1); // Show 3 months back
                                    final lastDay = DateTime(now.year, now.month + 1, 0);

                                    // Convert to Set<DateTime> for comparison
                                    final doneDateSet = doneDates.map((d) => DateTime.parse(d)).toSet();

                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Text('Progress History'),
                                        content: doneDateSet.isEmpty
                                            ? Text('No progress recorded yet.')
                                            : SizedBox(
                                                width: double.maxFinite,
                                                height: 400,
                                                child: TableCalendar(
                                                  firstDay: firstDay,
                                                  lastDay: lastDay,
                                                  focusedDay: now,
                                                  calendarFormat: CalendarFormat.month,
                                                  headerStyle: HeaderStyle(formatButtonVisible: false, titleCentered: true),
                                                  calendarBuilders: CalendarBuilders(
                                                    defaultBuilder: (context, day, focusedDay) {
                                                      final isDone = doneDateSet.contains(DateTime(day.year, day.month, day.day));
                                                      return Container(
                                                        alignment: Alignment.center,
                                                        decoration: BoxDecoration(
                                                          color: isDone ? Colors.green[400] : Colors.red[100],
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: Text(
                                                          '${day.day}',
                                                          style: TextStyle(color: Colors.black),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close'))
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Tooltip(
                                message: 'Delete Habit',
                                child: IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text('Delete Habit'),
                                        content: Text('Are you sure you want to delete "${habit['name']}" and all its progress?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
                                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete')),
                                        ],
                                      ),
                                    );
                                    if (context.mounted && confirm == true) {
                                      await habitProv.deleteHabit(habit['id']);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.0),
                          TreeAnimation(stage: habit['stage']),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: () => _showAddProgressDialog(context, habitProv, habit['id']),
                                child: Text('Add Progress'),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _showRemoveProgressDialog(context, habitProv, habit['id']),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: Text('Remove Progress'),
                              ),
                              if (habit['health'] == 0 && habit['revive_count'] > 0) ...[
                                SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => habitProv.reviveHabit(habit['id']),
                                  child: Text('Revive (${habit['revive_count']} left)'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddHabitScreen())),
        child: Icon(Icons.add),
      ),
    );
  }

  void _showAddProgressDialog(BuildContext context, HabitProvider habitProvider, int habitId) {
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Progress'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 16.0),
                  Row(
                    children: [
                      Text('Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}'),
                      Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (context.mounted && picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                        child: Text('Pick Date'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                TextButton(
                  onPressed: () {
                    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
                    habitProvider.addProgress(habitId, 1, dateStr);
                    Navigator.pop(context);
                  },
                  child: Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRemoveProgressDialog(BuildContext context, HabitProvider habitProvider, int habitId) {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedDate;
        return AlertDialog(
          title: Text('Remove Progress'),
          content: FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.getProgress(habitId),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return SizedBox(height: 50, child: Center(child: CircularProgressIndicator()));
              }
              final entries = snapshot.data ?? [];
              if (entries.isEmpty) return Text('No progress to remove.');
              final dates = entries
                  .map((e) => e['date'].toString().split('T')[0])
                  .toSet()
                  .toList();
              selectedDate ??= dates.first;
              return StatefulBuilder(
                builder: (context, setState) {
                  return DropdownButton<String>(
                    value: selectedDate,
                    items: dates.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setState(() => selectedDate = v),
                  );
                },
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
            TextButton(
              onPressed: () {
                if (selectedDate != null) {
                  habitProvider.removeProgressByDate(habitId, selectedDate!);
                }
                Navigator.pop(context);
              },
              child: Text('Remove'),
            ),
          ],
        );
      },
    );
  }
}
