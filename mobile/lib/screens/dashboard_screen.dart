import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
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

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiClient>().getDashboard();
  }

  Future<void> _reload() async {
    final future = context.read<ApiClient>().getDashboard();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
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
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: StatTile(label: 'Tokens', value: Text('${d.tokenCount}'))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        label: 'Data quality',
                        value: Wrap(
                          spacing: 6,
                          children: d.dataQualityCounts.entries
                              .where((e) => e.value > 0)
                              .map((e) => Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 13)))
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (d.clusterExposure.isNotEmpty) ...[
                  const Text('Cluster exposure', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...d.clusterExposure.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(c.cluster)),
                          Text('${c.tokenCount} · ${c.tickers.join(', ')}',
                              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (d.movers.isNotEmpty) ...[
                  const Text('Movers (24h)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...d.movers.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(m.ticker)),
                          DeltaText(value: m.change24hPct),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (d.upcomingCatalysts.isNotEmpty) ...[
                  const Text('Upcoming catalysts', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...d.upcomingCatalysts.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${c.ticker} · ${c.eventType} in ${c.daysUntil}d — ${c.description}'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Tokens', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...d.tokens.map((t) => _TokenRow(token: t)),
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
      contentPadding: EdgeInsets.zero,
      title: Text(token.ticker, style: const TextStyle(fontWeight: FontWeight.w600)),
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
