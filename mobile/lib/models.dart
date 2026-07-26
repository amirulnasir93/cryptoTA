// Mirrors packages/shared/src/index.ts -- the same API contract the web
// frontend consumes, just modeled as Dart classes instead of TS interfaces.

int? _asInt(dynamic v) => v == null ? null : (v as num).toInt();
double? _asDouble(dynamic v) => v == null ? null : (v as num).toDouble();
List<String> _asStringList(dynamic v) => v == null ? [] : List<String>.from(v as List);

class Label {
  final int id;
  final String name;
  final String? color;

  Label({required this.id, required this.name, this.color});

  factory Label.fromJson(Map<String, dynamic> json) =>
      Label(id: json['id'] as int, name: json['name'] as String, color: json['color'] as String?);
}

class TokenDeployment {
  final int id;
  final String chain;
  final String? contractAddress;
  final bool isPrimaryLiquidity;
  final String? notes;

  TokenDeployment({
    required this.id,
    required this.chain,
    this.contractAddress,
    required this.isPrimaryLiquidity,
    this.notes,
  });

  factory TokenDeployment.fromJson(Map<String, dynamic> json) => TokenDeployment(
        id: json['id'] as int,
        chain: json['chain'] as String,
        contractAddress: json['contractAddress'] as String?,
        isPrimaryLiquidity: json['isPrimaryLiquidity'] as bool? ?? false,
        notes: json['notes'] as String?,
      );
}

class MetricSnapshot {
  final int id;
  final String fetchedAt;
  final String? imageUrl;
  final double? priceCoingecko;
  final double? priceDexscreener;
  final double? priceBinance;
  final double? priceMexc;
  final double? divergencePct;
  final double? marketCap;
  final double? fdv;
  final double? volume24h;
  final double? volumeToMcap;
  final double? change1hPct;
  final double? change24hPct;
  final double? change7dPct;
  final double? change30dPct;
  final double? ath;
  final double? drawdownFromAthPct;
  final double? atl;
  final double? aboveAtlPct;
  final double? circulatingSupply;
  final double? totalSupply;
  final double? floatPct;
  final double? tvl;
  final double? tvlChange30dPct;
  final String? dataQuality;
  final List<String> assessableHorizons;
  final String? gatingReason;

  MetricSnapshot({
    required this.id,
    required this.fetchedAt,
    this.imageUrl,
    this.priceCoingecko,
    this.priceDexscreener,
    this.priceBinance,
    this.priceMexc,
    this.divergencePct,
    this.marketCap,
    this.fdv,
    this.volume24h,
    this.volumeToMcap,
    this.change1hPct,
    this.change24hPct,
    this.change7dPct,
    this.change30dPct,
    this.ath,
    this.drawdownFromAthPct,
    this.atl,
    this.aboveAtlPct,
    this.circulatingSupply,
    this.totalSupply,
    this.floatPct,
    this.tvl,
    this.tvlChange30dPct,
    this.dataQuality,
    this.assessableHorizons = const [],
    this.gatingReason,
  });

  factory MetricSnapshot.fromJson(Map<String, dynamic> json) => MetricSnapshot(
        id: json['id'] as int,
        fetchedAt: json['fetchedAt'] as String,
        imageUrl: json['imageUrl'] as String?,
        priceCoingecko: _asDouble(json['priceCoingecko']),
        priceDexscreener: _asDouble(json['priceDexscreener']),
        priceBinance: _asDouble(json['priceBinance']),
        priceMexc: _asDouble(json['priceMexc']),
        divergencePct: _asDouble(json['divergencePct']),
        marketCap: _asDouble(json['marketCap']),
        fdv: _asDouble(json['fdv']),
        volume24h: _asDouble(json['volume24h']),
        volumeToMcap: _asDouble(json['volumeToMcap']),
        change1hPct: _asDouble(json['change1hPct']),
        change24hPct: _asDouble(json['change24hPct']),
        change7dPct: _asDouble(json['change7dPct']),
        change30dPct: _asDouble(json['change30dPct']),
        ath: _asDouble(json['ath']),
        drawdownFromAthPct: _asDouble(json['drawdownFromAthPct']),
        atl: _asDouble(json['atl']),
        aboveAtlPct: _asDouble(json['aboveAtlPct']),
        circulatingSupply: _asDouble(json['circulatingSupply']),
        totalSupply: _asDouble(json['totalSupply']),
        floatPct: _asDouble(json['floatPct']),
        tvl: _asDouble(json['tvl']),
        tvlChange30dPct: _asDouble(json['tvlChange30dPct']),
        dataQuality: json['dataQuality'] as String?,
        assessableHorizons: _asStringList(json['assessableHorizons']),
        gatingReason: json['gatingReason'] as String?,
      );
}

class Token {
  final int id;
  final String ticker;
  final String? projectName;
  final String? primaryChain;
  final String? coingeckoId;
  final String? defillamaSlug;
  final String? binanceSymbol;
  final String? mexcSymbol;
  final String? cluster;
  final String? notes;
  final String? collisionWarning;
  final String status;
  final List<TokenDeployment> deployments;
  final List<Label> labels;
  final MetricSnapshot? latestSnapshot;
  // A short (DeFi/Perp/DEX/L1/...) label derived from CoinGecko's raw
  // categories -- only populated once this token's Insight tab has been
  // fetched at least once this session (see AppRepository's category cache);
  // null otherwise rather than triggering an extra fetch for every token on
  // every price refresh.
  final String? category;

  Token({
    required this.id,
    required this.ticker,
    this.projectName,
    this.primaryChain,
    this.coingeckoId,
    this.defillamaSlug,
    this.binanceSymbol,
    this.mexcSymbol,
    this.cluster,
    this.notes,
    this.collisionWarning,
    required this.status,
    this.deployments = const [],
    this.labels = const [],
    this.latestSnapshot,
    this.category,
  });

  factory Token.fromJson(Map<String, dynamic> json) => Token(
        id: json['id'] as int,
        ticker: json['ticker'] as String,
        projectName: json['projectName'] as String?,
        primaryChain: json['primaryChain'] as String?,
        coingeckoId: json['coingeckoId'] as String?,
        defillamaSlug: json['defillamaSlug'] as String?,
        binanceSymbol: json['binanceSymbol'] as String?,
        mexcSymbol: json['mexcSymbol'] as String?,
        cluster: json['cluster'] as String?,
        notes: json['notes'] as String?,
        collisionWarning: json['collisionWarning'] as String?,
        status: json['status'] as String,
        deployments:
            (json['deployments'] as List? ?? []).map((d) => TokenDeployment.fromJson(d as Map<String, dynamic>)).toList(),
        labels: (json['labels'] as List? ?? []).map((l) => Label.fromJson(l as Map<String, dynamic>)).toList(),
        latestSnapshot:
            json['latestSnapshot'] == null ? null : MetricSnapshot.fromJson(json['latestSnapshot'] as Map<String, dynamic>),
      );
}

class Catalyst {
  final int id;
  final int tokenId;
  final String eventDate;
  final String eventType;
  final String description;
  final double? sizePctOfSupply;
  final String? sourceUrl;

  Catalyst({
    required this.id,
    required this.tokenId,
    required this.eventDate,
    required this.eventType,
    required this.description,
    this.sizePctOfSupply,
    this.sourceUrl,
  });

  factory Catalyst.fromJson(Map<String, dynamic> json) => Catalyst(
        id: json['id'] as int,
        tokenId: json['tokenId'] as int,
        eventDate: json['eventDate'] as String,
        eventType: json['eventType'] as String,
        description: json['description'] as String,
        sizePctOfSupply: _asDouble(json['sizePctOfSupply']),
        sourceUrl: json['sourceUrl'] as String?,
      );
}

class ClusterSibling {
  final int id;
  final String ticker;
  final String? projectName;
  final MetricSnapshot? latestSnapshot;

  ClusterSibling({required this.id, required this.ticker, this.projectName, this.latestSnapshot});

  factory ClusterSibling.fromJson(Map<String, dynamic> json) => ClusterSibling(
        id: json['id'] as int,
        ticker: json['ticker'] as String,
        projectName: json['projectName'] as String?,
        latestSnapshot:
            json['latestSnapshot'] == null ? null : MetricSnapshot.fromJson(json['latestSnapshot'] as Map<String, dynamic>),
      );
}

class TokenDetail extends Token {
  final List<MetricSnapshot> history;
  final List<Catalyst> catalysts;
  final List<ClusterSibling> clusterSiblings;

  TokenDetail({
    required super.id,
    required super.ticker,
    super.projectName,
    super.primaryChain,
    super.coingeckoId,
    super.defillamaSlug,
    super.binanceSymbol,
    super.mexcSymbol,
    super.cluster,
    super.notes,
    super.collisionWarning,
    required super.status,
    super.deployments,
    super.labels,
    super.latestSnapshot,
    this.history = const [],
    this.catalysts = const [],
    this.clusterSiblings = const [],
  });

  factory TokenDetail.fromJson(Map<String, dynamic> json) {
    final token = Token.fromJson(json);
    return TokenDetail(
      id: token.id,
      ticker: token.ticker,
      projectName: token.projectName,
      primaryChain: token.primaryChain,
      coingeckoId: token.coingeckoId,
      defillamaSlug: token.defillamaSlug,
      binanceSymbol: token.binanceSymbol,
      mexcSymbol: token.mexcSymbol,
      cluster: token.cluster,
      notes: token.notes,
      collisionWarning: token.collisionWarning,
      status: token.status,
      deployments: token.deployments,
      labels: token.labels,
      latestSnapshot: token.latestSnapshot,
      history: (json['history'] as List? ?? []).map((h) => MetricSnapshot.fromJson(h as Map<String, dynamic>)).toList(),
      catalysts: (json['catalysts'] as List? ?? []).map((c) => Catalyst.fromJson(c as Map<String, dynamic>)).toList(),
      clusterSiblings:
          (json['clusterSiblings'] as List? ?? []).map((c) => ClusterSibling.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }
}

class ClusterExposure {
  final String cluster;
  final int tokenCount;
  final List<String> tickers;

  ClusterExposure({required this.cluster, required this.tokenCount, required this.tickers});

  factory ClusterExposure.fromJson(Map<String, dynamic> json) => ClusterExposure(
        cluster: json['cluster'] as String,
        tokenCount: json['tokenCount'] as int,
        tickers: _asStringList(json['tickers']),
      );
}

class UpcomingCatalyst extends Catalyst {
  final String ticker;
  final int daysUntil;

  UpcomingCatalyst({
    required super.id,
    required super.tokenId,
    required super.eventDate,
    required super.eventType,
    required super.description,
    super.sizePctOfSupply,
    super.sourceUrl,
    required this.ticker,
    required this.daysUntil,
  });

  factory UpcomingCatalyst.fromJson(Map<String, dynamic> json) {
    final c = Catalyst.fromJson(json);
    return UpcomingCatalyst(
      id: c.id,
      tokenId: c.tokenId,
      eventDate: c.eventDate,
      eventType: c.eventType,
      description: c.description,
      sizePctOfSupply: c.sizePctOfSupply,
      sourceUrl: c.sourceUrl,
      ticker: json['ticker'] as String,
      daysUntil: json['daysUntil'] as int,
    );
  }
}

class Mover {
  final String ticker;
  final int tokenId;
  final double? change24hPct;

  Mover({required this.ticker, required this.tokenId, this.change24hPct});

  factory Mover.fromJson(Map<String, dynamic> json) => Mover(
        ticker: json['ticker'] as String,
        tokenId: json['tokenId'] as int,
        change24hPct: _asDouble(json['change24hPct']),
      );
}

class DashboardSummary {
  final String generatedAt;
  final int tokenCount;
  final Map<String, int> dataQualityCounts;
  final List<ClusterExposure> clusterExposure;
  final List<UpcomingCatalyst> upcomingCatalysts;
  final List<Mover> movers;
  final List<Token> tokens;

  DashboardSummary({
    required this.generatedAt,
    required this.tokenCount,
    required this.dataQualityCounts,
    required this.clusterExposure,
    required this.upcomingCatalysts,
    required this.movers,
    required this.tokens,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        generatedAt: json['generatedAt'] as String,
        tokenCount: json['tokenCount'] as int,
        dataQualityCounts: Map<String, int>.from(json['dataQualityCounts'] as Map),
        clusterExposure:
            (json['clusterExposure'] as List? ?? []).map((c) => ClusterExposure.fromJson(c as Map<String, dynamic>)).toList(),
        upcomingCatalysts: (json['upcomingCatalysts'] as List? ?? [])
            .map((c) => UpcomingCatalyst.fromJson(c as Map<String, dynamic>))
            .toList(),
        movers: (json['movers'] as List? ?? []).map((m) => Mover.fromJson(m as Map<String, dynamic>)).toList(),
        tokens: (json['tokens'] as List? ?? []).map((t) => Token.fromJson(t as Map<String, dynamic>)).toList(),
      );
}

class ConflictLogEntry {
  final int id;
  final String ticker;
  final String detectedAt;
  final String field;
  final String? localValue;
  final String? sheetValue;
  final String resolution;

  ConflictLogEntry({
    required this.id,
    required this.ticker,
    required this.detectedAt,
    required this.field,
    this.localValue,
    this.sheetValue,
    required this.resolution,
  });

  factory ConflictLogEntry.fromJson(Map<String, dynamic> json) => ConflictLogEntry(
        id: json['id'] as int,
        ticker: json['ticker'] as String,
        detectedAt: json['detectedAt'] as String,
        field: json['field'] as String,
        localValue: json['localValue'] as String?,
        sheetValue: json['sheetValue'] as String?,
        resolution: json['resolution'] as String,
      );
}

class AnalysisPoint {
  final String timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double? rsi;
  final double? stochRsiK;
  final double? stochRsiD;
  final double? macd;
  final double? macdSignal;
  final double? macdHistogram;
  final double obv;

  AnalysisPoint({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.rsi,
    this.stochRsiK,
    this.stochRsiD,
    this.macd,
    this.macdSignal,
    this.macdHistogram,
    required this.obv,
  });

  factory AnalysisPoint.fromJson(Map<String, dynamic> json) => AnalysisPoint(
        timestamp: json['timestamp'] as String,
        open: (json['open'] as num).toDouble(),
        high: (json['high'] as num).toDouble(),
        low: (json['low'] as num).toDouble(),
        close: (json['close'] as num).toDouble(),
        volume: (json['volume'] as num).toDouble(),
        rsi: _asDouble(json['rsi']),
        stochRsiK: _asDouble(json['stochRsiK']),
        stochRsiD: _asDouble(json['stochRsiD']),
        macd: _asDouble(json['macd']),
        macdSignal: _asDouble(json['macdSignal']),
        macdHistogram: _asDouble(json['macdHistogram']),
        obv: (json['obv'] as num).toDouble(),
      );
}

class DivergenceFlag {
  final String indicator;
  final String type;
  final String fromDate;
  final String toDate;

  DivergenceFlag({required this.indicator, required this.type, required this.fromDate, required this.toDate});

  factory DivergenceFlag.fromJson(Map<String, dynamic> json) => DivergenceFlag(
        indicator: json['indicator'] as String,
        type: json['type'] as String,
        fromDate: json['fromDate'] as String,
        toDate: json['toDate'] as String,
      );
}

class KeyLevel {
  final double price;
  final String type; // "support" | "resistance"
  final int touches;

  KeyLevel({required this.price, required this.type, required this.touches});

  factory KeyLevel.fromJson(Map<String, dynamic> json) => KeyLevel(
        price: (json['price'] as num).toDouble(),
        type: json['type'] as String,
        touches: json['touches'] as int,
      );
}

class ChannelLine {
  final String fromTimestamp;
  final double fromPrice;
  final String toTimestamp;
  final double toPrice;

  ChannelLine({required this.fromTimestamp, required this.fromPrice, required this.toTimestamp, required this.toPrice});

  factory ChannelLine.fromJson(Map<String, dynamic> json) => ChannelLine(
        fromTimestamp: json['fromTimestamp'] as String,
        fromPrice: (json['fromPrice'] as num).toDouble(),
        toTimestamp: json['toTimestamp'] as String,
        toPrice: (json['toPrice'] as num).toDouble(),
      );
}

class TrendChannel {
  final ChannelLine upper;
  final ChannelLine lower;

  TrendChannel({required this.upper, required this.lower});

  factory TrendChannel.fromJson(Map<String, dynamic> json) =>
      TrendChannel(upper: ChannelLine.fromJson(json['upper'] as Map<String, dynamic>), lower: ChannelLine.fromJson(json['lower'] as Map<String, dynamic>));
}

/// Mirrors TokenAnalysisResult (a TS union) as available/unavailable state
/// on one class, since Dart doesn't discriminate unions as cleanly as TS.
class TokenAnalysisResult {
  final bool available;
  final String? reason;
  final int? tokenId;
  final String? ticker;
  final String? interval;
  final List<AnalysisPoint> points;
  final List<DivergenceFlag> divergences;
  final String? trendState;
  final String? trendBasis;
  final List<KeyLevel> keyLevels;
  final TrendChannel? trendChannel;

  TokenAnalysisResult.unavailable(this.reason)
      : available = false,
        tokenId = null,
        ticker = null,
        interval = null,
        points = const [],
        divergences = const [],
        trendState = null,
        trendBasis = null,
        keyLevels = const [],
        trendChannel = null;

  /// Used both when parsing a JSON response (see [fromJson]) and when the
  /// analysis is computed directly on-device from ported indicator logic
  /// (see repository.dart's getTokenAnalysis) -- same shape either way.
  TokenAnalysisResult.fromComputed({
    required this.tokenId,
    required this.ticker,
    required this.interval,
    required this.points,
    required this.divergences,
    required this.trendState,
    required this.trendBasis,
    required this.keyLevels,
    required this.trendChannel,
  })  : available = true,
        reason = null;

  factory TokenAnalysisResult.fromJson(Map<String, dynamic> json) {
    if (json['available'] == false) return TokenAnalysisResult.unavailable(json['reason'] as String);
    final trend = json['trend'] as Map<String, dynamic>;
    return TokenAnalysisResult.fromComputed(
      tokenId: json['tokenId'] as int,
      ticker: json['ticker'] as String,
      interval: json['interval'] as String,
      points: (json['points'] as List).map((p) => AnalysisPoint.fromJson(p as Map<String, dynamic>)).toList(),
      divergences: (json['divergences'] as List).map((d) => DivergenceFlag.fromJson(d as Map<String, dynamic>)).toList(),
      trendState: trend['state'] as String,
      trendBasis: trend['basis'] as String,
      keyLevels: (json['keyLevels'] as List).map((k) => KeyLevel.fromJson(k as Map<String, dynamic>)).toList(),
      trendChannel: json['trendChannel'] == null ? null : TrendChannel.fromJson(json['trendChannel'] as Map<String, dynamic>),
    );
  }
}

class TokenInsightLinks {
  final List<String> homepage;
  final String? twitter;
  final String? telegram;
  final String? subreddit;
  final List<String> github;
  final List<String> chat;

  TokenInsightLinks({
    required this.homepage,
    this.twitter,
    this.telegram,
    this.subreddit,
    required this.github,
    required this.chat,
  });

  factory TokenInsightLinks.fromJson(Map<String, dynamic> json) => TokenInsightLinks(
        homepage: _asStringList(json['homepage']),
        twitter: json['twitter'] as String?,
        telegram: json['telegram'] as String?,
        subreddit: json['subreddit'] as String?,
        github: _asStringList(json['github']),
        chat: _asStringList(json['chat']),
      );
}

class TokenInsightResult {
  final bool available;
  final String? reason;
  final String? description;
  final List<String> categories;
  final String? genesisDate;
  final int? marketCapRank;
  final double? sentimentUpPct;
  final double? sentimentDownPct;
  final TokenInsightLinks? links;
  final int? watchlistPortfolioUsers;
  final int? redditSubscribers;
  final int? telegramUserCount;
  final double? redditAveragePosts48h;
  final double? redditAverageComments48h;
  final int? redditAccountsActive48h;
  final int? stars;
  final int? forks;
  final int? contributors;
  final int? commitCount4Weeks;

  TokenInsightResult.unavailable(this.reason)
      : available = false,
        description = null,
        categories = const [],
        genesisDate = null,
        marketCapRank = null,
        sentimentUpPct = null,
        sentimentDownPct = null,
        links = null,
        watchlistPortfolioUsers = null,
        redditSubscribers = null,
        telegramUserCount = null,
        redditAveragePosts48h = null,
        redditAverageComments48h = null,
        redditAccountsActive48h = null,
        stars = null,
        forks = null,
        contributors = null,
        commitCount4Weeks = null;

  /// Used both when parsing a JSON response (see [fromJson]) and when built
  /// directly on-device from the CoinGecko coin-detail connector (see
  /// repository.dart's getTokenInsight).
  TokenInsightResult.fromComputed({
    required this.description,
    required this.categories,
    required this.genesisDate,
    required this.marketCapRank,
    required this.sentimentUpPct,
    required this.sentimentDownPct,
    required this.links,
    required this.watchlistPortfolioUsers,
    required this.redditSubscribers,
    required this.telegramUserCount,
    required this.redditAveragePosts48h,
    required this.redditAverageComments48h,
    required this.redditAccountsActive48h,
    required this.stars,
    required this.forks,
    required this.contributors,
    required this.commitCount4Weeks,
  })  : available = true,
        reason = null;

  factory TokenInsightResult.fromJson(Map<String, dynamic> json) {
    if (json['available'] == false) return TokenInsightResult.unavailable(json['reason'] as String);
    final community = json['community'] as Map<String, dynamic>;
    final developer = json['developer'] as Map<String, dynamic>;
    return TokenInsightResult.fromComputed(
      description: json['description'] as String?,
      categories: _asStringList(json['categories']),
      genesisDate: json['genesisDate'] as String?,
      marketCapRank: _asInt(json['marketCapRank']),
      sentimentUpPct: _asDouble(json['sentimentUpPct']),
      sentimentDownPct: _asDouble(json['sentimentDownPct']),
      links: TokenInsightLinks.fromJson(json['links'] as Map<String, dynamic>),
      watchlistPortfolioUsers: _asInt(json['watchlistPortfolioUsers']),
      redditSubscribers: _asInt(community['redditSubscribers']),
      telegramUserCount: _asInt(community['telegramUserCount']),
      redditAveragePosts48h: _asDouble(community['redditAveragePosts48h']),
      redditAverageComments48h: _asDouble(community['redditAverageComments48h']),
      redditAccountsActive48h: _asInt(community['redditAccountsActive48h']),
      stars: _asInt(developer['stars']),
      forks: _asInt(developer['forks']),
      contributors: _asInt(developer['pullRequestContributors']),
      commitCount4Weeks: _asInt(developer['commitCount4Weeks']),
    );
  }
}
