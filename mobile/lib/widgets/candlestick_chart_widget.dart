import 'package:candlesticks/candlesticks.dart';
import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';

/// Candlestick + volume rendering for the Technical Analysis tab, using the
/// `candlesticks` package for genuinely native pinch-zoom/pan/crosshair
/// (fl_chart's CandlestickChart has none of that built in -- confirmed by
/// reading its source earlier -- so a hand-rolled zoom on top of it never
/// felt as smooth as a purpose-built chart's own gesture handling).
///
/// One real tradeoff from switching: this package has no overlay API for
/// arbitrary lines, so the key-levels/trend-channel line overlay built for
/// the old fl_chart version doesn't carry over -- that data now shows only
/// as the text list already displayed below the chart, not as drawn lines.
///
/// `candles` must be newest-first here (index 0 = newest) per the package's
/// own contract -- the opposite of AnalysisPoint's chronological order, so
/// the list is reversed once when building it.
class CandlestickChartWidget extends StatelessWidget {
  final List<AnalysisPoint> points;
  final CandlesticksController controller;

  const CandlestickChartWidget({super.key, required this.points, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final candles = [
      for (var i = points.length - 1; i >= 0; i--)
        Candle(
          date: DateTime.parse(points[i].timestamp),
          open: points[i].open,
          high: points[i].high,
          low: points[i].low,
          close: points[i].close,
          volume: points[i].volume,
        ),
    ];

    final style = isDark
        ? CandleSticksStyle.dark(
            chartBackgroundColor: scheme.surfaceContainerHigh,
            gridLineColor: scheme.surfaceContainerHighest,
            axisTextColor: scheme.onSurfaceVariant,
            candleBullColor: upColor,
            candleBearColor: downColor,
          )
        : CandleSticksStyle.light(
            chartBackgroundColor: scheme.surfaceContainerHigh,
            gridLineColor: scheme.surfaceContainerHighest,
            axisTextColor: scheme.onSurfaceVariant,
            candleBullColor: upColor,
            candleBearColor: downColor,
          );

    return Candlesticks(candles: candles, controller: controller, style: style);
  }
}
