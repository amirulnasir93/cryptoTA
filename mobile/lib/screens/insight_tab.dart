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
    final scheme = Theme.of(context).colorScheme;
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
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomSafePadding(context)),
          children: [
            if (insight.description != null && insight.description!.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border(left: BorderSide(color: scheme.primary, width: 3)),
                ),
                padding: const EdgeInsets.all(16),
                child: Text(insight.description!.replaceAll('&nbsp;', ' '), style: const TextStyle(height: 1.5)),
              ),
              const SizedBox(height: 16),
            ],
            if (insight.categories.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: insight.categories
                    .take(12)
                    .map(
                      (c) => Chip(
                        label: Text(c, style: TextStyle(fontSize: 11, color: scheme.onTertiaryContainer)),
                        backgroundColor: scheme.tertiaryContainer,
                        side: BorderSide.none,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (links.isNotEmpty) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: links
                    .map(
                      (l) => ActionChip(
                        avatar: Icon(Icons.open_in_new_rounded, size: 14, color: scheme.primary),
                        label: Text(l.$1),
                        backgroundColor: scheme.primaryContainer.withValues(alpha: 0.5),
                        side: BorderSide.none,
                        onPressed: () => _open(l.$2),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.1,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                if (insight.marketCapRank != null)
                  StatTile(
                    label: 'Market cap rank',
                    icon: Icons.leaderboard_rounded,
                    iconColor: scheme.primary,
                    value: Text('#${insight.marketCapRank}'),
                  ),
                if (insight.sentimentUpPct != null)
                  StatTile(
                    label: 'Sentiment',
                    icon: Icons.thumbs_up_down_rounded,
                    iconColor: scheme.primary,
                    value: Row(
                      children: [
                        Text('${insight.sentimentUpPct}%', style: TextStyle(color: upColor)),
                        Text(' / ', style: TextStyle(color: scheme.onSurfaceVariant)),
                        Text('${insight.sentimentDownPct}%', style: TextStyle(color: downColor)),
                      ],
                    ),
                  ),
                if (insight.watchlistPortfolioUsers != null)
                  StatTile(
                    label: 'CoinGecko watchlists',
                    icon: Icons.visibility_rounded,
                    iconColor: scheme.primary,
                    value: Text('${insight.watchlistPortfolioUsers}'),
                  ),
                if (insight.redditSubscribers != null)
                  StatTile(
                    label: 'Reddit subs',
                    icon: Icons.forum_rounded,
                    iconColor: brandBlue,
                    value: Text('${insight.redditSubscribers}'),
                  ),
                if (insight.redditAccountsActive48h != null)
                  StatTile(
                    label: 'Reddit active (48h)',
                    icon: Icons.groups_rounded,
                    iconColor: brandBlue,
                    value: Text('${insight.redditAccountsActive48h}'),
                  ),
                if (insight.redditAveragePosts48h != null)
                  StatTile(
                    label: 'Reddit posts (48h avg)',
                    icon: Icons.article_rounded,
                    iconColor: brandBlue,
                    value: Text(insight.redditAveragePosts48h!.toStringAsFixed(1)),
                  ),
                if (insight.telegramUserCount != null)
                  StatTile(
                    label: 'Telegram members',
                    icon: Icons.send_rounded,
                    iconColor: brandBlue,
                    value: Text('${insight.telegramUserCount}'),
                  ),
                if (insight.stars != null)
                  StatTile(
                    label: 'GitHub stars',
                    icon: Icons.star_rounded,
                    iconColor: scheme.tertiary,
                    value: Text('${insight.stars}'),
                  ),
                if (insight.forks != null)
                  StatTile(
                    label: 'GitHub forks',
                    icon: Icons.call_split_rounded,
                    iconColor: scheme.tertiary,
                    value: Text('${insight.forks}'),
                  ),
                if (insight.contributors != null)
                  StatTile(
                    label: 'Contributors',
                    icon: Icons.group_rounded,
                    iconColor: scheme.tertiary,
                    value: Text('${insight.contributors}'),
                  ),
                if (insight.commitCount4Weeks != null)
                  StatTile(
                    label: 'Commits (4wk)',
                    icon: Icons.commit_rounded,
                    iconColor: scheme.tertiary,
                    value: Text('${insight.commitCount4Weeks}'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
