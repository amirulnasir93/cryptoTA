import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models.dart';
import 'common.dart';

/// Candlestick rendering for the mobile app's Technical Analysis tab.
///
/// This is deliberately simpler than the web app's lightweight-charts-based
/// PriceChart: fl_chart's CandlestickChartData has no clean way to overlay
/// arbitrary line series (key levels / trend channel) on top of a
/// candlestick series the way lightweight-charts does, so those are shown as
/// a text list below the chart instead of plotted lines. Full parity is a
/// possible future improvement, not attempted here.
class CandlestickChartWidget extends StatelessWidget {
  final List<AnalysisPoint> points;
  const CandlestickChartWidget({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final spots = <CandlestickSpot>[
      for (var i = 0; i < points.length; i++)
        CandlestickSpot(x: i.toDouble(), open: points[i].open, high: points[i].high, low: points[i].low, close: points[i].close),
    ];

    final lows = points.map((p) => p.low);
    final highs = points.map((p) => p.high);
    final minY = lows.reduce((a, b) => a < b ? a : b);
    final maxY = highs.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.08;

    final labelStep = (points.length / 4).ceil().clamp(1, points.length);

    return CandlestickChart(
      CandlestickChartData(
        candlestickSpots: spots,
        minY: minY - pad,
        maxY: maxY + pad,
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: true, border: Border.all(color: Theme.of(context).dividerColor)),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(value.toStringAsFixed(_precisionFor(value)), style: const TextStyle(fontSize: 10)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: labelStep.toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                final d = DateTime.parse(points[i].timestamp);
                return SideTitleWidget(
                  meta: meta,
                  child: Text('${d.month}/${d.day}', style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        candlestickPainter: DefaultCandlestickPainter(
          candlestickStyleProvider: (spot, index) {
            final color = spot.isUp ? upColor : downColor;
            return CandlestickStyle(
              lineColor: color,
              lineWidth: 1,
              bodyStrokeColor: color,
              bodyStrokeWidth: 0,
              bodyFillColor: color,
              bodyWidth: 4,
              bodyRadius: 1,
            );
          },
        ),
      ),
    );
  }

  int _precisionFor(double price) {
    final p = price.abs();
    if (p >= 100) return 2;
    if (p >= 1) return 4;
    if (p >= 0.01) return 6;
    return 8;
  }
}
