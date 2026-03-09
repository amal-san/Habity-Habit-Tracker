import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // REQUIRED PACKAGE: flutter pub add fl_chart
import '../models/habit.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Habit? _selectedHabit;
  final int _currentYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    final box = Hive.box<Habit>('habitsBox');
    if (box.isNotEmpty) {
      _selectedHabit = box.values.first;
    }
  }

  // --- STAT CALCULATIONS ---

  int _getTotalCompletions() {
    if (_selectedHabit == null) return 0;
    return _selectedHabit!.completedDays.length;
  }

  String _getCompletionRate() {
    if (_selectedHabit == null || _selectedHabit!.completedDays.isEmpty) return '0%';

    _selectedHabit!.completedDays.sort();
    DateTime firstDay = _selectedHabit!.completedDays.first;
    DateTime today = DateTime.now();
    int daysSinceStart = today.difference(firstDay).inDays + 1;

    if (daysSinceStart <= 0) return '0%';

    double rate = (_selectedHabit!.completedDays.length / daysSinceStart) * 100;
    return '${rate.clamp(0, 100).toStringAsFixed(1)}%';
  }

  List<int> _getMonthlyData() {
    List<int> monthlyCounts = List.filled(12, 0);
    if (_selectedHabit == null) return monthlyCounts;

    for (var date in _selectedHabit!.completedDays) {
      if (date.year == _currentYear) {
        monthlyCounts[date.month - 1]++;
      }
    }
    return monthlyCounts;
  }

  Map<String, int> _calculateStreaks() {
    if (_selectedHabit == null || _selectedHabit!.completedDays.isEmpty) {
      return {'current': 0, 'best': 0};
    }

    // 1. Strip the time out of the dates so we are only comparing pure days, and remove duplicates
    List<DateTime> uniqueDays = _selectedHabit!.completedDays
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList();

    uniqueDays.sort(); // Oldest to newest

    if (uniqueDays.isEmpty) return {'current': 0, 'best': 0};

    int bestStreak = 1;
    int tempStreak = 1;

    // 2. Calculate the Best Streak of all time
    for (int i = 1; i < uniqueDays.length; i++) {
      if (uniqueDays[i].difference(uniqueDays[i - 1]).inDays == 1) {
        tempStreak++; // Days are consecutive
      } else {
        tempStreak = 1; // Streak broken, reset temp
      }
      if (tempStreak > bestStreak) {
        bestStreak = tempStreak;
      }
    }

    // 3. Calculate the Current Streak
    int currentStreak = 0;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final yesterday = today.subtract(const Duration(days: 1));

    // If the habit wasn't done today OR yesterday, the current streak is officially dead (0)
    if (!uniqueDays.contains(today) && !uniqueDays.contains(yesterday)) {
      currentStreak = 0;
    } else {
      currentStreak = 1;
      // Count backwards from the most recently logged day to see how long the active chain is
      for (int i = uniqueDays.length - 1; i > 0; i--) {
        if (uniqueDays[i].difference(uniqueDays[i - 1]).inDays == 1) {
          currentStreak++;
        } else {
          break; // Chain broken!
        }
      }
    }

    return {'current': currentStreak, 'best': bestStreak};
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    final box = Hive.box<Habit>('habitsBox');
    final habits = box.values.toList();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: habits.isEmpty
            ? Center(child: Text('No habits found.', style: TextStyle(color: textColor)))
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TOP BAR: Habit Selector & Done Button ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: habits.map((habit) {
                          final isSelected = _selectedHabit == habit;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedHabit = habit),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? Color(habit.colorValue) : cardColor,
                                shape: BoxShape.circle,
                                border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                              ),
                              child: Icon(
                                IconData(habit.iconCodePoint, fontFamily: 'MaterialIcons'),
                                color: isSelected ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                size: 24,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BCD4), // Teal accent
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),

            // --- HEADER: Habit Info (Fixed Overflow!) ---
            if (_selectedHabit != null)
              if (_selectedHabit!.streakGoalInterval == 'None')
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Color(_selectedHabit!.colorValue), size: 30),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          'You need to set a streak goal for this habit to see streak data. You can do this when editing the habit.',
                          style: TextStyle(color: Colors.grey.shade400, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // DRAW THE STREAK CARDS!
                Builder(
                    builder: (context) {
                      final streaks = _calculateStreaks();
                      return Row(
                        children: [
                          Expanded(
                              child: _buildStatCard(
                                  'Current Streak',
                                  '${streaks['current']}',
                                  Icons.local_fire_department_rounded,
                                  cardColor, textColor, _selectedHabit!.colorValue
                              )
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                              child: _buildStatCard(
                                  'Best Streak',
                                  '${streaks['best']}',
                                  Icons.emoji_events_rounded,
                                  cardColor, textColor, _selectedHabit!.colorValue
                              )
                          ),
                        ],
                      );
                    }
                ),
                const SizedBox(height: 40),
              ],
            // --- YEAR NAVIGATOR ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.chevron_left, color: textColor),
                  Text('$_currentYear', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  Icon(Icons.chevron_right, color: textColor),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Main Content Area
            Expanded(
              // FIXED: Added SingleChildScrollView to prevent bottom overflow warnings
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // --- HEATMAP (Simplified Grid) ---
                    Container(
                      height: 140,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                      child: GridView.builder(
                        scrollDirection: Axis.horizontal,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: 365,
                        itemBuilder: (context, index) {
                          DateTime day = DateTime(_currentYear, 1, 1).add(Duration(days: index));
                          bool isDone = _selectedHabit!.completedDays.any((d) => d.year == day.year && d.month == day.month && d.day == day.day);
                          return Container(
                            decoration: BoxDecoration(
                              color: isDone ? Color(_selectedHabit!.colorValue) : (isDark ? const Color(0xFF2A2D40) : Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 15),

                    // --- STATS CARDS ---
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Completions', '${_getTotalCompletions()}', Icons.tag, cardColor, textColor, _selectedHabit!.colorValue)),
                        const SizedBox(width: 15),
                        Expanded(child: _buildStatCard('Completion Rate', _getCompletionRate(), Icons.percent, cardColor, textColor, _selectedHabit!.colorValue)),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // --- MONTHLY SMOOTH FILLED LINE GRAPH (MATCHES REFERENCE!) ---
                    if (_selectedHabit != null)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Completions / Month', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                                Icon(Icons.insights, color: Color(_selectedHabit!.colorValue)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 120, // slightly taller chart
                              child: LineChart(
                                _buildLineChartData(isDark, cardColor),
                              ),
                            )
                          ],
                        ),
                      ),
                    const SizedBox(height: 15),

                    // --- STREAK GOAL WARNING ---
                    if (_selectedHabit != null && _selectedHabit!.streakGoalInterval == 'None')
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Color(_selectedHabit!.colorValue), size: 30),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                'You need to set a streak goal for this habit to see streak data. You can do this when editing the habit.',
                                style: TextStyle(color: Colors.grey.shade400, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STATS CARD HELPER ---

  Widget _buildStatCard(String title, String value, IconData icon, Color cardColor, Color textColor, int colorValue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(), // Spacer
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Color(colorValue).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: Color(colorValue), size: 20),
              )
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ],
      ),
    );
  }

  // --- FL_CHART DATA HELPER (MATCHES GRAPH STYLE!) ---

  LineChartData _buildLineChartData(bool isDark, Color cardColor) {
    if (_selectedHabit == null) return LineChartData();

    final habitColor = Color(_selectedHabit!.colorValue);
    final monthlyCounts = _getMonthlyData();
    double maxY = monthlyCounts.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxY == 0) maxY = 10; // set min height

    // Convert monthly counts to FlSpot data
    final spots = monthlyCounts.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.toDouble());
    }).toList();

    return LineChartData(
      gridData: const FlGridData(show: false), // Hide grid lines like reference
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide Y-axis numbers
        // X-Axis (Month Labels)
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (double value, TitleMeta meta) {
              const style = TextStyle(color: Colors.grey, fontSize: 10);
              String text;
              switch (value.toInt()) {
                case 1: text = 'F'; break; // Feb
                case 2: text = 'M'; break; // Mar
                case 3: text = 'A'; break; // Apr
                case 4: text = 'M'; break; // May
                case 5: text = 'J'; break; // Jun
                case 6: text = 'J'; break; // Jul
                case 7: text = 'A'; break; // Aug
                case 8: text = 'S'; break; // Sep
                case 9: text = 'O'; break; // Oct
                case 10: text = 'N'; break; // Nov
                default: text = '';
              }
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(text, style: style),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 11,
      minY: 0,
      maxY: maxY + (maxY * 0.1),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          preventCurveOverShooting: true,
          color: habitColor,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: habitColor.withOpacity(0.2),
          ),
        ),
      ],
    );
  }
}