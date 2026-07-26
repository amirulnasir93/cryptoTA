import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repository.dart';
import '../models.dart';
import '../market_events.dart';
import '../widgets/common.dart';
import '../widgets/skeleton.dart';
import 'token_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

// Cycles none -> biggest gainers first -> biggest losers first -> none.
enum _GainSort { none, desc, asc }

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardSummary> _future;
  String? _selectedLabel;
  _GainSort _gainSort = _GainSort.none;

  // Logged (not just surfaced via FutureBuilder's snapshot.error) so a
  // real device failure shows up in `adb logcat` instead of only ever being
  // visible as a truncated error string on screen.
  Future<DashboardSummary> _fetch() {
    return context.read<AppRepository>().refreshAndGetDashboard().catchError((Object e, StackTrace st) {
      debugPrint('Dashboard load failed: $e\n$st');
      throw e;
    });
  }

  @override
  void initState() {
    super.initState();
    // Refresh on open -- there's no background cron on the phone, see the plan.
    _future = _fetch();
  }

  Future<void> _reload() async {
    final future = _fetch();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: FutureBuilder<DashboardSummary>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const DashboardSkeleton();
          }
          if (snapshot.hasError) {
            return ErrorRetry(message: 'Could not load dashboard: ${snapshot.error}', onRetry: _reload);
          }
          final d = snapshot.data!;
          final goodCount = d.dataQualityCounts['Good'] ?? 0;
          final allLabels = {for (final t in d.tokens) for (final l in t.labels) l.name}.toList()..sort();
          final filteredTokens = _selectedLabel == null
              ? d.tokens
              : d.tokens.where((t) => t.labels.any((l) => l.name == _selectedLabel)).toList();
          final visibleTokens = [...filteredTokens];
          if (_gainSort != _GainSort.none) {
            visibleTokens.sort((a, b) {
              final av = a.latestSnapshot?.change24hPct;
              final bv = b.latestSnapshot?.change24hPct;
              if (av == null && bv == null) return 0;
              if (av == null) return 1; // no data sorts to the bottom regardless of direction
              if (bv == null) return -1;
              return _gainSort == _GainSort.desc ? bv.compareTo(av) : av.compareTo(bv);
            });
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Watchlist',
                        icon: Icons.dashboard_customize_rounded,
                        value: Text('${d.tokenCount}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: 'Data quality',
                        icon: Icons.verified_rounded,
                        value: Text('$goodCount good', style: TextStyle(color: upColor)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (d.movers.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: 'Top mover (24h)',
                          icon: Icons.trending_up_rounded,
                          value: Row(
                            children: [
                              Text(d.movers.first.ticker),
                              const SizedBox(width: 8),
                              DeltaText(value: d.movers.first.change24hPct, fontSize: 13),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          label: 'Clusters',
                          icon: Icons.hub_rounded,
                          value: Text('${d.clusterExposure.length}'),
                        ),
                      ),
                    ],
                  ),
                if (d.fearGreed != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: 'Fear & greed',
                          icon: Icons.speed_rounded,
                          iconColor: d.fearGreed!.value >= 55
                              ? upColor
                              : d.fearGreed!.value <= 45
                                  ? downColor
                                  : null,
                          value: Text(
                            '${d.fearGreed!.value}',
                            style: TextStyle(
                              color: d.fearGreed!.value >= 55
                                  ? upColor
                                  : d.fearGreed!.value <= 45
                                      ? downColor
                                      : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          label: 'Market mood',
                          icon: Icons.psychology_rounded,
                          value: Text(d.fearGreed!.classification, style: const TextStyle(fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ],
                if (d.clusterExposure.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const SectionHeader(
                    title: 'Cluster exposure',
                    subtitle: "Tokens in the same cluster don't move independently.",
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < d.clusterExposure.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                          ListTile(
                            title: Text(d.clusterExposure[i].cluster, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(d.clusterExposure[i].tickers.join(', ')),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${d.clusterExposure[i].tokenCount}',
                                style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (d.upcomingCatalysts.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Upcoming catalysts', subtitle: 'Next 90 days'),
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < d.upcomingCatalysts.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                          ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: scheme.tertiaryContainer,
                              child: Icon(Icons.event_rounded, size: 16, color: scheme.onTertiaryContainer),
                            ),
                            title: Text('${d.upcomingCatalysts[i].ticker} · ${d.upcomingCatalysts[i].eventType}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(d.upcomingCatalysts[i].description),
                            trailing: Text(
                              d.upcomingCatalysts[i].daysUntil == 0 ? 'today' : 'in ${d.upcomingCatalysts[i].daysUntil}d',
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (d.marketEvents.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const SectionHeader(
                    title: 'Upcoming market events',
                    subtitle: 'Next 90 days · via CoinMarketCal',
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < d.marketEvents.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                          ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: scheme.tertiaryContainer,
                              child: Icon(Icons.public_rounded, size: 16, color: scheme.onTertiaryContainer),
                            ),
                            title: Text(
                              '${d.marketEvents[i].ticker} · ${marketEventTypeLabel(d.marketEvents[i].eventType)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(d.marketEvents[i].description),
                            trailing: Text(
                              d.marketEvents[i].daysUntil == 0 ? 'today' : 'in ${d.marketEvents[i].daysUntil}d',
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Tokens',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedLabel != null)
                        TextButton(
                          onPressed: () => setState(() => _selectedLabel = null),
                          child: const Text('Clear filter'),
                        ),
                      IconButton(
                        tooltip: switch (_gainSort) {
                          _GainSort.none => 'Sort by 24h gain',
                          _GainSort.desc => 'Sorted: biggest gainers first',
                          _GainSort.asc => 'Sorted: biggest losers first',
                        },
                        icon: Icon(switch (_gainSort) {
                          _GainSort.none => Icons.sort_rounded,
                          _GainSort.desc => Icons.arrow_downward_rounded,
                          _GainSort.asc => Icons.arrow_upward_rounded,
                        }),
                        color: _gainSort == _GainSort.none ? scheme.onSurfaceVariant : scheme.primary,
                        onPressed: () => setState(() {
                          _gainSort = switch (_gainSort) {
                            _GainSort.none => _GainSort.desc,
                            _GainSort.desc => _GainSort.asc,
                            _GainSort.asc => _GainSort.none,
                          };
                        }),
                      ),
                    ],
                  ),
                ),
                if (allLabels.isNotEmpty) ...[
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: allLabels
                          .map(
                            (name) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text(name),
                                selected: _selectedLabel == name,
                                onSelected: (selected) => setState(() => _selectedLabel = selected ? name : null),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < visibleTokens.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                        _TokenRow(token: visibleTokens[i]),
                      ],
                      if (visibleTokens.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('No tokens with this label.', style: TextStyle(color: scheme.onSurfaceVariant)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TokenRow extends StatelessWidget {
  final Token token;
  const _TokenRow({required this.token});

  @override
  Widget build(BuildContext context) {
    final s = token.latestSnapshot;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: TickerAvatar(ticker: token.ticker, imageUrl: s?.imageUrl),
      title: Text(token.ticker, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (token.projectName != null && token.projectName!.isNotEmpty) Text(token.projectName!),
          if (token.labels.isNotEmpty || token.category != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (token.category != null) CategoryBadge(category: token.category!),
                  for (final l in token.labels)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l.name,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: scheme.onSecondaryContainer),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DataQualityBadge(quality: s?.dataQuality),
          const SizedBox(width: 8),
          DeltaText(value: s?.change24hPct),
        ],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TokenDetailScreen(tokenId: token.id))),
    );
  }
}
