// Ported from packages/backend/src/connectors/coingecko.ts -- called
// directly from the phone now instead of through a backend passthrough.
import 'http_client.dart';

const _cg = "https://api.coingecko.com/api/v3";

class CoingeckoMarket {
  final String id;
  final double? currentPrice;
  final double? marketCap;
  final double? fullyDilutedValuation;
  final double? totalVolume;
  final double? change24hPct;
  final double? change7dPct;
  final double? change30dPct;
  final double? ath;
  final double? athChangePct;
  final double? circulatingSupply;
  final double? totalSupply;

  CoingeckoMarket({
    required this.id,
    this.currentPrice,
    this.marketCap,
    this.fullyDilutedValuation,
    this.totalVolume,
    this.change24hPct,
    this.change7dPct,
    this.change30dPct,
    this.ath,
    this.athChangePct,
    this.circulatingSupply,
    this.totalSupply,
  });

  factory CoingeckoMarket.fromJson(Map<String, dynamic> j) => CoingeckoMarket(
        id: j['id'] as String,
        currentPrice: (j['current_price'] as num?)?.toDouble(),
        marketCap: (j['market_cap'] as num?)?.toDouble(),
        fullyDilutedValuation: (j['fully_diluted_valuation'] as num?)?.toDouble(),
        totalVolume: (j['total_volume'] as num?)?.toDouble(),
        change24hPct: (j['price_change_percentage_24h_in_currency'] as num?)?.toDouble(),
        change7dPct: (j['price_change_percentage_7d_in_currency'] as num?)?.toDouble(),
        change30dPct: (j['price_change_percentage_30d_in_currency'] as num?)?.toDouble(),
        ath: (j['ath'] as num?)?.toDouble(),
        athChangePct: (j['ath_change_percentage'] as num?)?.toDouble(),
        circulatingSupply: (j['circulating_supply'] as num?)?.toDouble(),
        totalSupply: (j['total_supply'] as num?)?.toDouble(),
      );
}

/// Batched lookup: N tokens in one call, not N.
Future<Map<String, CoingeckoMarket>> fetchCoingeckoMarkets(List<String> ids, {String? apiKey}) async {
  if (ids.isEmpty) return {};
  final params = {
    'vs_currency': 'usd',
    'ids': ids.join(','),
    'price_change_percentage': '24h,7d,30d',
    'sparkline': 'false',
  };
  final uri = Uri.parse('$_cg/coins/markets').replace(queryParameters: params);
  final headers = <String, String>{if (apiKey != null && apiKey.isNotEmpty) 'x-cg-demo-api-key': apiKey};
  final data = await fetchJson(uri.toString(), headers: headers);
  if (data == null) return {};
  final list = (data as List).map((e) => CoingeckoMarket.fromJson(e as Map<String, dynamic>));
  return {for (final m in list) m.id: m};
}

class MarketChartPoint {
  final int timestamp;
  final double value;
  MarketChartPoint(this.timestamp, this.value);
}

class MarketChartResult {
  final List<MarketChartPoint> prices;
  final List<MarketChartPoint> volumes;
  MarketChartResult(this.prices, this.volumes);
}

class MarketChartOutcome {
  final bool ok;
  final MarketChartResult? data;
  final FetchFailureReason? reason;
  MarketChartOutcome.ok(this.data)
      : ok = true,
        reason = null;
  MarketChartOutcome.failed(this.reason)
      : ok = false,
        data = null;
}

/// Historical daily-ish price/volume series. Returns the failure reason (not
/// just null) so a rate-limited request can be told apart from a genuine
/// data gap -- the keyless public tier's rate limit is low enough that the
/// former happens routinely under normal use (this exact distinction was
/// added to the web backend this session after a live "no historical data"
/// report turned out to just be rate-limiting).
Future<MarketChartOutcome> fetchCoingeckoMarketChart(String id, {int days = 90, String? apiKey}) async {
  final params = {'vs_currency': 'usd', 'days': '$days'};
  final uri = Uri.parse('$_cg/coins/$id/market_chart').replace(queryParameters: params);
  final headers = <String, String>{if (apiKey != null && apiKey.isNotEmpty) 'x-cg-demo-api-key': apiKey};

  final result = await fetchJsonWithReason(uri.toString(), headers: headers);
  if (!result.ok) return MarketChartOutcome.failed(result.reason);

  final data = result.data as Map<String, dynamic>;
  final prices = (data['prices'] as List)
      .map((p) => MarketChartPoint((p[0] as num).toInt(), (p[1] as num).toDouble()))
      .toList();
  final volumes = (data['total_volumes'] as List)
      .map((p) => MarketChartPoint((p[0] as num).toInt(), (p[1] as num).toDouble()))
      .toList();
  return MarketChartOutcome.ok(MarketChartResult(prices, volumes));
}

class CoingeckoCoinDetail {
  final String? description;
  final List<String> categories;
  final String? genesisDate;
  final int? marketCapRank;
  final double? sentimentUpPct;
  final double? sentimentDownPct;
  final List<String> homepage;
  final List<String> chatUrls;
  final String? twitterScreenName;
  final String? telegramChannel;
  final String? subredditUrl;
  final List<String> githubRepos;
  final int? redditSubscribers;
  final int? telegramUserCount;
  final int? stars;
  final int? forks;
  final int? subscribers;
  final int? totalIssues;
  final int? closedIssues;
  final int? pullRequestsMerged;
  final int? pullRequestContributors;
  final int? commitCount4Weeks;

  CoingeckoCoinDetail({
    this.description,
    this.categories = const [],
    this.genesisDate,
    this.marketCapRank,
    this.sentimentUpPct,
    this.sentimentDownPct,
    this.homepage = const [],
    this.chatUrls = const [],
    this.twitterScreenName,
    this.telegramChannel,
    this.subredditUrl,
    this.githubRepos = const [],
    this.redditSubscribers,
    this.telegramUserCount,
    this.stars,
    this.forks,
    this.subscribers,
    this.totalIssues,
    this.closedIssues,
    this.pullRequestsMerged,
    this.pullRequestContributors,
    this.commitCount4Weeks,
  });

  factory CoingeckoCoinDetail.fromJson(Map<String, dynamic> j) {
    final links = j['links'] as Map<String, dynamic>?;
    final community = j['community_data'] as Map<String, dynamic>?;
    final developer = j['developer_data'] as Map<String, dynamic>?;
    return CoingeckoCoinDetail(
      description: (j['description'] as Map<String, dynamic>?)?['en'] as String?,
      categories: (j['categories'] as List?)?.cast<String>() ?? [],
      genesisDate: j['genesis_date'] as String?,
      marketCapRank: j['market_cap_rank'] as int?,
      sentimentUpPct: (j['sentiment_votes_up_percentage'] as num?)?.toDouble(),
      sentimentDownPct: (j['sentiment_votes_down_percentage'] as num?)?.toDouble(),
      homepage: (links?['homepage'] as List?)?.cast<String>().where((s) => s.isNotEmpty).toList() ?? [],
      chatUrls: (links?['chat_url'] as List?)?.cast<String>().where((s) => s.isNotEmpty).toList() ?? [],
      twitterScreenName: links?['twitter_screen_name'] as String?,
      telegramChannel: links?['telegram_channel_identifier'] as String?,
      subredditUrl: links?['subreddit_url'] as String?,
      githubRepos:
          ((links?['repos_url'] as Map<String, dynamic>?)?['github'] as List?)?.cast<String>() ?? [],
      redditSubscribers: (community?['reddit_subscribers'] as num?)?.toInt(),
      telegramUserCount: (community?['telegram_channel_user_count'] as num?)?.toInt(),
      stars: (developer?['stars'] as num?)?.toInt(),
      forks: (developer?['forks'] as num?)?.toInt(),
      subscribers: (developer?['subscribers'] as num?)?.toInt(),
      totalIssues: (developer?['total_issues'] as num?)?.toInt(),
      closedIssues: (developer?['closed_issues'] as num?)?.toInt(),
      pullRequestsMerged: (developer?['pull_requests_merged'] as num?)?.toInt(),
      pullRequestContributors: (developer?['pull_request_contributors'] as num?)?.toInt(),
      commitCount4Weeks: (developer?['commit_count_4_weeks'] as num?)?.toInt(),
    );
  }
}

Future<CoingeckoCoinDetail?> fetchCoingeckoCoinDetail(String id, {String? apiKey}) async {
  final params = {
    'localization': 'false',
    'tickers': 'false',
    'market_data': 'false',
    'community_data': 'true',
    'developer_data': 'true',
    'sparkline': 'false',
  };
  final uri = Uri.parse('$_cg/coins/$id').replace(queryParameters: params);
  final headers = <String, String>{if (apiKey != null && apiKey.isNotEmpty) 'x-cg-demo-api-key': apiKey};
  final data = await fetchJson(uri.toString(), headers: headers);
  if (data == null) return null;
  return CoingeckoCoinDetail.fromJson(data as Map<String, dynamic>);
}

class CoingeckoSearchResult {
  final String id;
  final String name;
  final String symbol;
  CoingeckoSearchResult(this.id, this.name, this.symbol);
}

Future<List<CoingeckoSearchResult>> searchCoingecko(String query) async {
  if (query.trim().isEmpty) return [];
  final uri = Uri.parse('$_cg/search').replace(queryParameters: {'query': query});
  final data = await fetchJson(uri.toString());
  if (data == null) return [];
  final coins = (data['coins'] as List?) ?? [];
  return coins
      .take(10)
      .map((c) => CoingeckoSearchResult(c['id'] as String, c['name'] as String, c['symbol'] as String))
      .toList();
}
