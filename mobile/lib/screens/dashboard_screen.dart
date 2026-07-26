import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repository.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'token_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardSummary> _future;

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
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorRetry(message: 'Could not load dashboard: ${snapshot.error}', onRetry: _reload);
          }
          final d = snapshot.data!;
          final goodCount = d.dataQualityCounts['Good'] ?? 0;
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
                const SizedBox(height: 24),
                const SectionHeader(title: 'Tokens'),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < d.tokens.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                        _TokenRow(token: d.tokens[i]),
                      ],
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
    return ListTile(
      leading: TickerAvatar(ticker: token.ticker, imageUrl: s?.imageUrl),
      title: Text(token.ticker, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(token.projectName ?? ''),
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
