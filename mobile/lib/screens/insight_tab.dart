import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../repository.dart';
import '../models.dart';
import '../widgets/common.dart';

class InsightTab extends StatefulWidget {
  final int tokenId;
  const InsightTab({super.key, required this.tokenId});

  @override
  State<InsightTab> createState() => _InsightTabState();
}

class _InsightTabState extends State<InsightTab> {
  late Future<TokenInsightResult> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppRepository>().getTokenInsight(widget.tokenId);
  }

  void _reload() {
    setState(() => _future = context.read<AppRepository>().getTokenInsight(widget.tokenId));
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TokenInsightResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorRetry(message: '${snapshot.error}', onRetry: _reload);
        }
        final insight = snapshot.data!;
        if (!insight.available) {
          return Center(
            child: Padding(padding: const EdgeInsets.all(24), child: Text(insight.reason ?? 'Unavailable')),
          );
        }

        final links = <(String, String)>[
          for (final url in insight.links!.homepage) (Uri.tryParse(url)?.host ?? url, url),
          if (insight.links!.twitter != null) ('Twitter / X', insight.links!.twitter!),
          if (insight.links!.telegram != null) ('Telegram', insight.links!.telegram!),
          if (insight.links!.subreddit != null) ('Reddit', insight.links!.subreddit!),
          for (final url in insight.links!.chat) (Uri.tryParse(url)?.host ?? url, url),
          for (final url in insight.links!.github) ('GitHub', url),
        ];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              "Sourced from CoinGecko's public project data",
              style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 8),
            if (insight.description != null && insight.description!.isNotEmpty) ...[
              Text(insight.description!.replaceAll('&nbsp;', ' ')),
              const SizedBox(height: 12),
            ],
            if (insight.categories.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: insight.categories
                    .take(12)
                    .map((c) => Chip(label: Text(c, style: const TextStyle(fontSize: 11)), padding: EdgeInsets.zero))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (links.isNotEmpty) ...[
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: links
                    .map((l) => InkWell(onTap: () => _open(l.$2), child: Text(l.$1, style: const TextStyle(color: Colors.blue))))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (insight.marketCapRank != null) StatTile(label: 'Market cap rank', value: Text('#${insight.marketCapRank}')),
                if (insight.sentimentUpPct != null)
                  StatTile(label: 'Sentiment', value: Text('${insight.sentimentUpPct}% up / ${insight.sentimentDownPct}% down')),
                if (insight.redditSubscribers != null)
                  StatTile(label: 'Reddit subs', value: Text('${insight.redditSubscribers}')),
                if (insight.telegramUserCount != null)
                  StatTile(label: 'Telegram members', value: Text('${insight.telegramUserCount}')),
                if (insight.stars != null) StatTile(label: 'GitHub stars', value: Text('${insight.stars}')),
                if (insight.forks != null) StatTile(label: 'GitHub forks', value: Text('${insight.forks}')),
                if (insight.contributors != null) StatTile(label: 'Contributors', value: Text('${insight.contributors}')),
                if (insight.commitCount4Weeks != null)
                  StatTile(label: 'Commits (4wk)', value: Text('${insight.commitCount4Weeks}')),
              ],
            ),
          ],
        );
      },
    );
  }
}
