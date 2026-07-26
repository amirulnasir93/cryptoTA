import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models.dart';
import 'common.dart';

/// Shared bottom (date) axis config so every indicator panel lines up with
/// the candlestick chart above it -- same point-index x-domain, same label
/// cadence, just without repeating the closure in five different widgets.
FlTitlesData _axisTitles(BuildContext context, List<AnalysisPoint> points, {bool showDates = true}) {
  final labelStep = (points.length / 4).ceil().clamp(1, points.length);
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 9)),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: showDates,
        reservedSize: 22,
        interval: labelStep.toDouble(),
        getTitlesWidget: (value, meta) {
          final i = value.round();
          if (i < 0 || i >= points.length) return const SizedBox.shrink();
          final d = DateTime.parse(points[i].timestamp);
          return SideTitleWidget(meta: meta, child: Text('${d.month}/${d.day}', style: const TextStyle(fontSize: 9)));
        },
      ),
    ),
  );
}

List<FlSpot> _spots(List<AnalysisPoint> points, double? Function(AnalysisPoint) get) {
  final out = <FlSpot>[];
  for (var i = 0; i < points.length; i++) {
    final v = get(points[i]);
    if (v != null) out.add(FlSpot(i.toDouble(), v));
  }
  return out;
}

class _Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double height;
  final Widget chart;
  const _Panel({required this.title, this.subtitle, required this.height, required this.chart});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 8),
            SizedBox(height: height, child: chart),
          ],
        ),
      ),
    );
  }
}

/// RSI, 0-100 scale, with faint reference lines at the standard 30/70
/// oversold/overbought thresholds -- a read of current momentum, not itself
/// a trade signal.
class RsiChart extends StatelessWidget {
  final List<AnalysisPoint> points;
  const RsiChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'RSI',
      height: 120,
      chart: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: 0,
          maxY: 100,
          titlesData: _axisTitles(context, points),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 50),
          borderData: FlBorderData(show: true, border: Border.all(color: Theme.of(context).dividerColor)),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(y: 70, color: downColor.withValues(alpha: 0.5), strokeWidth: 1, dashArray: [4, 4]),
              HorizontalLine(y: 30, color: upColor.withValues(alpha: 0.5), strokeWidth: 1, dashArray: [4, 4]),
            ],
          ),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: _spots(points, (p) => p.rsi),
              color: brandBlue,
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stochastic RSI's %K/%D pair -- more sensitive (and noisier) than plain
/// RSI, per Skills/indicators.md's own caveat.
class StochRsiChart extends StatelessWidget {
  final List<AnalysisPoint> points;
  const StochRsiChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Stochastic RSI',
      subtitle: '%K (solid) / %D (dashed)',
      height: 120,
      chart: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: 0,
          maxY: 100,
          titlesData: _axisTitles(context, points),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 50),
          borderData: FlBorderData(show: true, border: Border.all(color: Theme.of(context).dividerColor)),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(y: 80, color: downColor.withValues(alpha: 0.5), strokeWidth: 1, dashArray: [4, 4]),
              HorizontalLine(y: 20, color: upColor.withValues(alpha: 0.5), strokeWidth: 1, dashArray: [4, 4]),
            ],
          ),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: _spots(points, (p) => p.stochRsiK),
              color: brandPurple,
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: _spots(points, (p) => p.stochRsiD),
              color: brandBlue,
              barWidth: 1.5,
              dashArray: [4, 3],
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// MACD line + signal line, with the histogram (their difference) as its
/// own bar panel directly below -- kept as two separate mini-charts rather
/// than one perfectly-overlaid combo chart, since fl_chart's line and bar
/// charts don't share a single widget type to layer without risking
/// misaligned axes that can't be visually checked without a device on hand.
class MacdChart extends StatelessWidget {
  final List<AnalysisPoint> points;
  const MacdChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final histValues = points.map((p) => p.macdHistogram).whereType<double>().toList();
    final histMax = histValues.isEmpty ? 1.0 : histValues.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        _Panel(
          title: 'MACD',
          subtitle: 'MACD (solid) / Signal (dashed)',
          height: 110,
          chart: LineChart(
            LineChartData(
              minX: 0,
              maxX: (points.length - 1).toDouble(),
              titlesData: _axisTitles(context, points, showDates: false),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: true, border: Border.all(color: Theme.of(context).dividerColor)),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: _spots(points, (p) => p.macd),
                  color: brandPurple,
                  barWidth: 1.5,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: _spots(points, (p) => p.macdSignal),
                  color: brandBlue,
                  barWidth: 1.5,
                  dashArray: [4, 3],
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _Panel(
          title: 'MACD histogram',
          height: 90,
          chart: BarChart(
            BarChartData(
              minY: -histMax * 1.1,
              maxY: histMax * 1.1,
              titlesData: _axisTitles(context, points),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: true, border: Border.all(color: Theme.of(context).dividerColor)),
              barTouchData: BarTouchData(enabled: false),
              barGroups: [
                for (var i = 0; i < points.length; i++)
                  if (points[i].macdHistogram != null)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].macdHistogram!,
                          color: points[i].macdHistogram! >= 0 ? upColor : downColor,
                          width: (points.length > 60) ? 1.5 : 3,
                        ),
                      ],
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// On-Balance Volume -- only its slope/relationship to price carries
/// information, never its absolute level (see Skills/indicators.md).
class ObvChart extends StatelessWidget {
  final List<AnalysisPoint> points;
  const ObvChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'OBV',
      subtitle: 'Only the slope carries information -- the absolute level does not.',
      height: 100,
      chart: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          titlesData: _axisTitles(context, points),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: true, border: Border.all(color: Theme.of(context).dividerColor)),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].obv)],
              color: brandBlue,
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: brandBlue.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }
}
