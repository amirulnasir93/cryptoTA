import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repository.dart';
import '../models.dart';
import '../widgets/candlestick_chart_widget.dart';
import '../widgets/common.dart';

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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                padding: const EdgeInsets.all(12),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TrendBadge(state: result.trendState!),
                      Text('${result.points.length} candles', style: TextStyle(color: Theme.of(context).hintColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A mechanical read of current indicator state -- not a price forecast.',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(height: 280, child: CandlestickChartWidget(points: result.points)),
                  const SizedBox(height: 16),
                  if (result.divergences.isNotEmpty) ...[
                    const Text('Divergence', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    ...result.divergences.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${d.type[0].toUpperCase()}${d.type.substring(1)} ${d.indicator} divergence',
                          style: TextStyle(color: d.type == 'bullish' ? upColor : downColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (result.keyLevels.isNotEmpty) ...[
                    const Text('Key levels', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Support/resistance from actual swing structure, not a prediction.',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                    ),
                    const SizedBox(height: 6),
                    ...result.keyLevels.map(
                      (k) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              k.type == 'resistance' ? 'Resistance' : 'Support',
                              style: TextStyle(color: k.type == 'resistance' ? downColor : upColor, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Text(k.price.toStringAsFixed(k.price < 1 ? 6 : 2)),
                            const SizedBox(width: 8),
                            Text('${k.touches}× touched', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (result.trendChannel != null) ...[
                    const Text('Trend channel', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'A line through the last 2 swing highs/lows, extended forward -- a geometric read of '
                      'current structure, invalidated the moment price breaks it. Not a prediction.',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                    ),
                    const SizedBox(height: 6),
                    Text('Upper: ${result.trendChannel!.upper.fromPrice.toStringAsFixed(4)} → '
                        '${result.trendChannel!.upper.toPrice.toStringAsFixed(4)}'),
                    Text('Lower: ${result.trendChannel!.lower.fromPrice.toStringAsFixed(4)} → '
                        '${result.trendChannel!.lower.toPrice.toStringAsFixed(4)}'),
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
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(state, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
