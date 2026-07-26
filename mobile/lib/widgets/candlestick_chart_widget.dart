import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models.dart';
import 'common.dart';

/// Candlestick rendering for the mobile app's Technical Analysis tab, with
/// key levels (support/resistance) and the trend channel overlaid directly
/// on the chart -- both purely structural/historical reads, never a price
/// prediction (see Skills/SKILL.md's "never predict prices" principle,
/// which this whole app follows).
///
/// fl_chart's CandlestickChartData shares AxisChartData's own
/// `extraLinesData` (confirmed against the installed fl_chart-1.2.0 source,
/// not assumed), so full-width horizontal lines -- exactly what a key level
/// is -- attach directly to the candlestick chart itself. A trend channel's
/// two lines are arbitrary two-point diagonal segments, though, which
/// `extraLinesData` genuinely can't express (only full horizontal/vertical
/// lines) -- those are drawn by stacking a second, transparent LineChart
/// with identical axis bounds/titlesData directly on top, the standard
/// fl_chart combo-chart technique.
class CandlestickChartWidget extends StatelessWidget {
  final List<AnalysisPoint> points;
  final List<KeyLevel> keyLevels;
  final TrendChannel? trendChannel;

  const CandlestickChartWidget({
    super.key,
    required this.points,
    this.keyLevels = const [],
    this.trendChannel,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final spots = <CandlestickSpot>[
      for (var i = 0; i < points.length; i++)
        CandlestickSpot(x: i.toDouble(), open: points[i].open, high: points[i].high, low: points[i].low, close: points[i].close),
    ];

    final lows = points.map((p) => p.low).toList();
    final highs = points.map((p) => p.high).toList();
    var minY = lows.reduce((a, b) => a < b ? a : b);
    var maxY = highs.reduce((a, b) => a > b ? a : b);
    // Key levels / trend channel endpoints can sit outside the candles' own
    // high/low range (a channel line is extended a few bars past the last
    // close) -- widen the Y range so nothing gets clipped off-chart.
    for (final level in keyLevels) {
      if (level.price < minY) minY = level.price;
      if (level.price > maxY) maxY = level.price;
    }
    if (trendChannel != null) {
      for (final price in [
        trendChannel!.upper.fromPrice,
        trendChannel!.upper.toPrice,
        trendChannel!.lower.fromPrice,
        trendChannel!.lower.toPrice,
      ]) {
        if (price < minY) minY = price;
        if (price > maxY) maxY = price;
      }
    }
    final pad = (maxY - minY) * 0.08;
    minY -= pad;
    maxY += pad;
    const minX = 0.0;
    final maxX = (points.length - 1).toDouble();

    final labelStep = (points.length / 4).ceil().clamp(1, points.length);

    final titlesData = FlTitlesData(
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
    );

    return Stack(
      children: [
        CandlestickChart(
          CandlestickChartData(
            candlestickSpots: spots,
            minY: minY,
            maxY: maxY,
            minX: minX,
            maxX: maxX,
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: true, border: Border.all(color: Theme.of(context).dividerColor)),
            titlesData: titlesData,
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
        ),
        // CandlestickChartData's own constructor doesn't forward
        // extraLinesData to its AxisChartData base (confirmed against the
        // installed fl_chart-1.2.0 source -- unlike LineChartData, which
        // does), so key levels (horizontal by nature) and the trend channel
        // (arbitrary diagonal segments, which extraLinesData can't express
        // even where it IS available) both go on this transparent LineChart
        // stacked on top instead, sharing the exact same axis bounds.
        if (keyLevels.isNotEmpty || trendChannel != null)
          IgnorePointer(
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                titlesData: titlesData,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    for (final level in keyLevels)
                      HorizontalLine(
                        y: level.price,
                        color: (level.type == 'resistance' ? downColor : upColor).withValues(alpha: 0.7),
                        strokeWidth: 1,
                        dashArray: const [6, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: level.type == 'resistance' ? downColor : upColor,
                          ),
                          labelResolver: (_) => level.price.toStringAsFixed(level.price < 1 ? 6 : 2),
                        ),
                      ),
                  ],
                ),
                lineBarsData: [
                  if (trendChannel != null) _channelLine(trendChannel!.upper, points, downColor),
                  if (trendChannel != null) _channelLine(trendChannel!.lower, points, upColor),
                ],
              ),
            ),
          ),
      ],
    );
  }

  LineChartBarData _channelLine(ChannelLine line, List<AnalysisPoint> points, Color color) {
    return LineChartBarData(
      spots: [
        FlSpot(_timestampToIndex(line.fromTimestamp, points), line.fromPrice),
        FlSpot(_timestampToIndex(line.toTimestamp, points), line.toPrice),
      ],
      color: color.withValues(alpha: 0.85),
      barWidth: 1.5,
      dotData: const FlDotData(show: false),
      dashArray: [4, 4],
    );
  }

  /// A trend channel's endpoints are timestamps, not point indices -- and
  /// the line is deliberately extended a few bars past the last real candle,
  /// so its "to" timestamp can fall beyond points.last. Extrapolates using
  /// the average spacing between candles rather than requiring an exact
  /// match, mirroring the web frontend's indexToTimestamp (the same
  /// conversion in reverse).
  double _timestampToIndex(String timestamp, List<AnalysisPoint> points) {
    final target = DateTime.parse(timestamp).millisecondsSinceEpoch;
    final times = points.map((p) => DateTime.parse(p.timestamp).millisecondsSinceEpoch).toList();
    if (target <= times.first) return 0;
    if (target >= times.last) {
      if (times.length < 2) return (points.length - 1).toDouble();
      final avgSpacing = (times.last - times.first) / (times.length - 1);
      if (avgSpacing <= 0) return (points.length - 1).toDouble();
      return (points.length - 1) + (target - times.last) / avgSpacing;
    }
    for (var i = 0; i < times.length - 1; i++) {
      if (target >= times[i] && target <= times[i + 1]) {
        final span = times[i + 1] - times[i];
        if (span <= 0) return i.toDouble();
        return i + (target - times[i]) / span;
      }
    }
    return (points.length - 1).toDouble();
  }

  int _precisionFor(double price) {
    final p = price.abs();
    if (p >= 100) return 2;
    if (p >= 1) return 4;
    if (p >= 0.01) return 6;
    return 8;
  }
}
