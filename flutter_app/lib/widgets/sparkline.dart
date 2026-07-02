import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// A tiny, axis-less trend line for use inside stat cards.
///
/// Renders [values] (oldest -> newest) as a smooth line with a soft gradient
/// fill beneath it. Designed to sit on a colored card, so it defaults to a
/// translucent white line; pass [color] to override.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.color = Colors.white,
    this.height = 26,
    this.lineWidth = 2,
  });

  final List<int> values;
  final Color color;
  final double height;
  final double lineWidth;

  @override
  Widget build(BuildContext context) {
    // Need at least two points to draw a meaningful line.
    if (values.length < 2) return SizedBox(height: height);

    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), values[i].toDouble()),
    ];

    final maxY = values.reduce((a, b) => a > b ? a : b).toDouble();
    // Give the line a little vertical headroom; keep a flat series visible.
    final topY = maxY <= 0 ? 1.0 : maxY * 1.15;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: 0,
          maxY: topY,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.28,
              preventCurveOverShooting: true,
              color: color.withValues(alpha: 0.95),
              barWidth: lineWidth,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.35),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}
