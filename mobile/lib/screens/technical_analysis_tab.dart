import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repository.dart';
import '../models.dart';
import '../widgets/candlestick_chart_widget.dart';
import '../widgets/common.dart';
import '../widgets/indicator_charts.dart';

const _intervals = ['15m', '1h', '2h', '4h', '1d', '2d', '3d', '1w', '1M'];

class TechnicalAnalysisTab extends StatefulWidget {
  final int tokenId;
  const TechnicalAnalysisTab({super.key, required this.tokenId});

  @override
  State<TechnicalAnalysisTab> createState() => _TechnicalAnalysisTabState();
}

class _TechnicalAnalysisTabState extends State<TechnicalAnalysisTab> {
  String _interval = '1d';
  late Future<TokenAnalysisResult> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AppRepository>().getTokenAnalysis(widget.tokenId, _interval);
  }

  void _setInterval(String interval) {
    setState(() {
      _interval = interval;
      _load();
    });
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
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ErrorRetry(message: '${snapshot.error}', onRetry: () => setState(_load));
              }
              final result = snapshot.data!;
              if (!result.available) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(result.reason ?? 'Unavailable', textAlign: TextAlign.center),
                  ),
                );
              }
              return ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomSafePadding(context)),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TrendBadge(state: result.trendState!),
                      Text('${result.points.length} candles', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A mechanical read of current indicator state -- not a price forecast.',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 12, 4),
                      child: SizedBox(
                        height: 280,
                        child: CandlestickChartWidget(
                          points: result.points,
                          keyLevels: result.keyLevels,
                          trendChannel: result.trendChannel,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  MacdChart(points: result.points),
                  const SizedBox(height: 8),
                  StochRsiChart(points: result.points),
                  const SizedBox(height: 8),
                  RsiChart(points: result.points),
                  const SizedBox(height: 8),
                  VolumeChart(points: result.points),
                  const SizedBox(height: 8),
                  ObvChart(points: result.points),
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
