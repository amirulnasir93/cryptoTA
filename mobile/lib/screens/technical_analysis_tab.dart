import 'package:candlesticks/candlesticks.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repository.dart';
import '../models.dart';
import '../widgets/candlestick_chart_widget.dart';
import '../widgets/common.dart';
import '../widgets/indicator_charts.dart';
import '../widgets/skeleton.dart';

const _intervals = ['15m', '1h', '2h', '4h', '1d', '2d', '3d', '1w', '1M'];

class TechnicalAnalysisTab extends StatefulWidget {
  final int tokenId;
  const TechnicalAnalysisTab({super.key, required this.tokenId});

  @override
  State<TechnicalAnalysisTab> createState() => _TechnicalAnalysisTabState();
}

class _TechnicalAnalysisTabState extends State<TechnicalAnalysisTab> {
  String _interval = '1d';
  ChartSource _source = ChartSource.coingecko;
  late Future<TokenAnalysisResult> _future;
  late CandlesticksController _chartController;
  int _totalPoints = 0;
  int _visibleStart = 0;
  int _visibleEnd = 0;

  @override
  void initState() {
    super.initState();
    _chartController = CandlesticksController()..addListener(_onViewportChanged);
    _load();
  }

  @override
  void dispose() {
    _chartController.removeListener(_onViewportChanged);
    _chartController.dispose();
    super.dispose();
  }

  void _load() {
    _future = context.read<AppRepository>().getTokenAnalysis(widget.tokenId, _interval, source: _source);
  }

  void _resetChart() {
    // Old candles' index range means nothing against a completely different
    // series -- a fresh controller (not just a reset viewport) also clears
    // its cached candle count/chart width from the previous data.
    _chartController.removeListener(_onViewportChanged);
    _chartController.dispose();
    _chartController = CandlesticksController()..addListener(_onViewportChanged);
    _visibleStart = 0;
    _visibleEnd = 0;
    _totalPoints = 0;
  }

  void _setInterval(String interval) {
    setState(() {
      _resetChart();
      _interval = interval;
      _load();
    });
  }

  void _setSource(ChartSource source) {
    setState(() {
      _resetChart();
      _source = source;
      _load();
    });
  }

  // The candlesticks package indexes candles newest-first (0 = newest),
  // opposite of AnalysisPoint's chronological order (0 = oldest) -- convert
  // its visible-range indices into ours so the indicator panels below can
  // slice the exact same window.
  void _onViewportChanged() {
    if (_totalPoints == 0) return;
    final viewport = _chartController.value;
    final firstPkg = _chartController.firstVisibleCandleIndexFor(viewport);
    final lastPkg = _chartController.lastVisibleCandleIndexFor(viewport);
    final start = (_totalPoints - 1 - lastPkg).clamp(0, _totalPoints - 1);
    final end = (_totalPoints - firstPkg).clamp(start + 1, _totalPoints);
    setState(() {
      _visibleStart = start;
      _visibleEnd = end;
    });
  }

  Widget _buildSourceToggle() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<ChartSource>(
          segments: const [
            ButtonSegment(value: ChartSource.coingecko, label: Text('CoinGecko')),
            ButtonSegment(value: ChartSource.binance, label: Text('Binance')),
          ],
          selected: {_source},
          showSelectedIcon: false,
          onSelectionChanged: (s) => _setSource(s.first),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        if (_source == ChartSource.binance) ...[
          const SizedBox(height: 4),
          Text(
            'Real exchange candles, no 365-day history cap.',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _intervals
                  .map(
                    (iv) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(label: Text(iv), selected: _interval == iv, onSelected: (_) => _setInterval(iv)),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<TokenAnalysisResult>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const TechnicalAnalysisSkeleton();
              }
              if (snapshot.hasError) {
                return ErrorRetry(message: '${snapshot.error}', onRetry: () => setState(_load));
              }
              final result = snapshot.data!;
              if (!result.available) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (result.binanceAvailable) ...[
                          _buildSourceToggle(),
                          const SizedBox(height: 16),
                        ],
                        Text(result.reason ?? 'Unavailable', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }

              if (_totalPoints != result.points.length) {
                _totalPoints = result.points.length;
                _visibleStart = 0;
                _visibleEnd = _totalPoints;
              }
              final indicatorPoints = result.points.sublist(_visibleStart, _visibleEnd);

              return ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomSafePadding(context)),
                children: [
                  if (result.binanceAvailable) ...[
                    _buildSourceToggle(),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TrendBadge(state: result.trendState!),
                      Text('${result.points.length} candles', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A mechanical read of current indicator state -- not a price forecast. Pinch to zoom, drag to pan.',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      height: 340,
                      child: CandlestickChartWidget(
                        key: ValueKey(_interval),
                        points: result.points,
                        controller: _chartController,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  MacdChart(points: indicatorPoints),
                  const SizedBox(height: 8),
                  StochRsiChart(points: indicatorPoints),
                  const SizedBox(height: 8),
                  RsiChart(points: indicatorPoints),
                  const SizedBox(height: 8),
                  ObvChart(points: indicatorPoints),
                  if (result.divergences.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Divergence'),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: result.divergences
                            .map(
                              (d) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      d.type == 'bullish' ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                      size: 16,
                                      color: d.type == 'bullish' ? upColor : downColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${d.type[0].toUpperCase()}${d.type.substring(1)} ${d.indicator} divergence',
                                      style: TextStyle(color: d.type == 'bullish' ? upColor : downColor, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  if (result.keyLevels.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const SectionHeader(
                      title: 'Key levels',
                      subtitle: 'Support/resistance from actual swing structure, not a prediction.',
                    ),
                    AppCard(
                      child: Column(
                        children: result.keyLevels
                            .map(
                              (k) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (k.type == 'resistance' ? downColor : upColor).withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        k.type == 'resistance' ? 'Resistance' : 'Support',
                                        style: TextStyle(
                                          color: k.type == 'resistance' ? downColor : upColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(k.price.toStringAsFixed(k.price < 1 ? 6 : 2), style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 8),
                                    Text('${k.touches}× touched', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  if (result.trendChannel != null) ...[
                    const SizedBox(height: 20),
                    const SectionHeader(
                      title: 'Trend channel',
                      subtitle: 'A line through the last 2 swing highs/lows, extended forward. Not a prediction.',
                    ),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Upper: ${result.trendChannel!.upper.fromPrice.toStringAsFixed(4)} → '
                              '${result.trendChannel!.upper.toPrice.toStringAsFixed(4)}'),
                          const SizedBox(height: 4),
                          Text('Lower: ${result.trendChannel!.lower.fromPrice.toStringAsFixed(4)} → '
                              '${result.trendChannel!.lower.toPrice.toStringAsFixed(4)}'),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final String state;
  const _TrendBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      'Uptrend' => upColor,
      'Downtrend' => downColor,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(state, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
