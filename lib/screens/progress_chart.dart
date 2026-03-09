import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ProgressChart extends StatelessWidget {
  const ProgressChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                // Dummy data: X is day, Y is completion amount
                spots: const [
                  FlSpot(0, 1),
                  FlSpot(1, 1.5),
                  FlSpot(2, 1.4),
                  FlSpot(3, 3.4),
                  FlSpot(4, 2),
                  FlSpot(5, 2.2),
                  FlSpot(6, 4),
                ],
                isCurved: true,
                color: Colors.blueAccent,
                barWidth: 4,
                dotData: FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.blueAccent.withOpacity(0.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}