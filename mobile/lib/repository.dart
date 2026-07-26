// Replaces api_client.dart: the phone's data layer now talks directly to the
// Google Sheet (via sheets_client.dart) and the price/market-data APIs (via
// connectors/*.dart), computing indicators locally (via indicators.dart) --
// no custom backend involved at all. See the approved plan
// (Google Sheet as the database) for the full rationale.
import 'models.dart';
import 'sheets_client.dart';
import 'known_collisions.dart';
import 'category.dart';
import 'candles.dart' as candles;
import 'gating.dart' as gating;
import 'indicators.dart' as ind;
import 'connectors/coingecko.dart' as cg;
import 'connectors/dexscreener.dart' as dex;
import 'connectors/defillama.dart' as llama;
import 'connectors/binance_compatible.dart' as exch;
import 'connectors/http_client.dart' show FetchFailureReason;

const _validStatuses = ['active', 'archived', 'removed'];
const _minCandlesForAnalysis = 40;

Future<void> _sleep(int ms) => Future.delayed(Duration(milliseconds: ms));

/// Mirrors packages/backend/src/jobs/syncDecision.ts's parseLabelList/
/// formatLabelList -- same comma-separated, alphabetically-sorted format, so
/// the phone and the web app's own Sheet sync agree on how the "Labels"
/// column is written.
List<String> parseLabelList(String value) =>
    value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

String formatLabelList(List<String> names) {
  final sorted = [...names]..sort((a, b) => a.compareTo(b));
  return sorted.join(', ');
}

class AppRepository {
  final SheetsClient sheets;
  String? coingeckoApiKey;
  AppRepository(this.sheets, {this.coingeckoApiKey});

  /// Last-fetched live metrics per ticker. Empty until [refreshPrices] has
  /// run at least once -- there is no persisted history on the phone (see
  /// the plan: CoinGecko's own /coins/markets response is already fresh
  /// 24h/7d/30d data per call, so there's nothing to store historically for
  /// the views that need it).
  final Map<String, MetricSnapshot> _snapshots = {};

  /// Simplified (DeFi/Perp/DEX/...) category per ticker, populated the first
  /// time a token's Insight tab is viewed this session -- not refetched on
  /// every price refresh, since it's a separate, heavier CoinGecko call and
  /// a project's category essentially never changes mid-session.
  final Map<String, String?> _categoryCache = {};

  Token _tokenFromRow(int rowNumber, List<String> row) {
    final ticker = row[0].trim().toUpperCase();
    final contract = row[3];
    final chain = row[2];
    return Token(
      id: rowNumber,
      ticker: ticker,
      projectName: row[1].isEmpty ? null : row[1],
      primaryChain: chain.isEmpty ? null : chain,
      coingeckoId: row[4].isEmpty ? null : row[4],
      defillamaSlug: row[5].isEmpty ? null : row[5],
      binanceSymbol: row[6].isEmpty ? null : row[6],
      mexcSymbol: row[7].isEmpty ? null : row[7],
      cluster: row[8].isEmpty ? null : row[8],
      notes: row[9].isEmpty ? null : row[9],
      collisionWarning: collisionWarningFor(ticker),
      status: _validStatuses.contains(row[11]) ? row[11] : 'active',
      deployments: contract.isEmpty
          ? []
          : [TokenDeployment(id: 0, chain: chain, contractAddress: contract, isPrimaryLiquidity: true)],
      labels: parseLabelList(row[10]).map((n) => Label(id: n.hashCode, name: n)).toList(),
      latestSnapshot: _snapshots[ticker],
      category: _categoryCache[ticker],
    );
  }

  List<String> _rowFromToken(Token t) {
    final contract = t.deployments.isNotEmpty ? (t.deployments.first.contractAddress ?? '') : '';
    return [
      t.ticker,
      t.projectName ?? '',
      t.primaryChain ?? '',
      contract,
      t.coingeckoId ?? '',
      t.defillamaSlug ?? '',
      t.binanceSymbol ?? '',
      t.mexcSymbol ?? '',
      t.cluster ?? '',
      t.notes ?? '',
      formatLabelList(t.labels.map((l) => l.name).toList()),
      t.status,
    ];
  }

  Future<List<Token>> _allTokenRows() async {
    final rows = await sheets.readRows(watchlistTab);
    return [for (var i = 0; i < rows.length; i++) _tokenFromRow(i + 2, rows[i])];
  }

  Future<List<Token>> listTokens({String? status}) async {
    final all = await _allTokenRows();
    if (status == 'all') return all;
    if (status != null) return all.where((t) => t.status == status).toList();
    return all.where((t) => t.status != 'removed').toList();
  }

  Future<List<Catalyst>> _catalystsFor(String ticker) async {
    final rows = await sheets.readRows(catalystsTab);
    final out = <Catalyst>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row[0].trim().toUpperCase() != ticker) continue;
      out.add(Catalyst(
        id: i + 2,
        tokenId: 0,
        eventDate: row[1],
        eventType: row[2].isEmpty ? 'other' : row[2],
        description: row[3],
        sizePctOfSupply: double.tryParse(row[4]),
        sourceUrl: row[5].isEmpty ? null : row[5],
      ));
    }
    out.sort((a, b) => a.eventDate.compareTo(b.eventDate));
    return out;
  }

  Future<TokenDetail> getToken(int rowNumber) async {
    final all = await _allTokenRows();
    final token = all.firstWhere((t) => t.id == rowNumber, orElse: () => throw StateError('Token not found'));
    final catalysts = await _catalystsFor(token.ticker);
    final siblings = token.cluster == null
        ? <ClusterSibling>[]
        : all
            .where((t) => t.cluster == token.cluster && t.id != token.id && t.status != 'removed')
            .map((t) => ClusterSibling(id: t.id, ticker: t.ticker, projectName: t.projectName, latestSnapshot: t.latestSnapshot))
            .toList();

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
      history: const [],
      catalysts: catalysts,
      clusterSiblings: siblings,
    );
  }

  Future<void> createToken(Map<String, dynamic> input) async {
    final token = Token(
      id: 0,
      ticker: (input['ticker'] as String).trim().toUpperCase(),
      projectName: input['projectName'] as String?,
      primaryChain: input['primaryChain'] as String?,
      coingeckoId: input['coingeckoId'] as String?,
      cluster: input['cluster'] as String?,
      status: 'active',
    );
    await sheets.appendRow(watchlistTab, _rowFromToken(token));
  }

  Future<void> _updateRowFields(int rowNumber, Map<String, dynamic> patch) async {
    final all = await _allTokenRows();
    final current = all.firstWhere((t) => t.id == rowNumber);
    final merged = Token(
      id: current.id,
      ticker: current.ticker,
      projectName: patch.containsKey('projectName') ? patch['projectName'] as String? : current.projectName,
      primaryChain: patch.containsKey('primaryChain') ? patch['primaryChain'] as String? : current.primaryChain,
      coingeckoId: patch.containsKey('coingeckoId') ? patch['coingeckoId'] as String? : current.coingeckoId,
      defillamaSlug: patch.containsKey('defillamaSlug') ? patch['defillamaSlug'] as String? : current.defillamaSlug,
      binanceSymbol: patch.containsKey('binanceSymbol') ? patch['binanceSymbol'] as String? : current.binanceSymbol,
      mexcSymbol: patch.containsKey('mexcSymbol') ? patch['mexcSymbol'] as String? : current.mexcSymbol,
      cluster: patch.containsKey('cluster') ? patch['cluster'] as String? : current.cluster,
      notes: patch.containsKey('notes') ? patch['notes'] as String? : current.notes,
      status: patch.containsKey('status') ? patch['status'] as String : current.status,
      deployments: current.deployments,
      labels: patch.containsKey('labels')
          ? (patch['labels'] as List<String>).map((n) => Label(id: n.hashCode, name: n)).toList()
          : current.labels,
      latestSnapshot: current.latestSnapshot,
    );
    await sheets.updateRow(watchlistTab, rowNumber, _rowFromToken(merged));
  }

  Future<void> updateToken(int rowNumber, Map<String, dynamic> input) => _updateRowFields(rowNumber, input);
  Future<void> archiveToken(int rowNumber) => _updateRowFields(rowNumber, {'status': 'archived'});
  Future<void> restoreToken(int rowNumber) => _updateRowFields(rowNumber, {'status': 'active'});
  // Soft delete only, matching the web backend's DELETE /tokens/:id -- never
  // a real row removal, so price/catalyst history for this ticker survives.
  Future<void> removeToken(int rowNumber) => _updateRowFields(rowNumber, {'status': 'removed'});

  Future<void> createCatalyst(Map<String, dynamic> input) async {
    await sheets.appendRow(catalystsTab, [
      (input['ticker'] as String).toUpperCase(),
      input['eventDate'] as String,
      input['eventType'] as String,
      input['description'] as String,
      input['sizePctOfSupply']?.toString() ?? '',
      input['sourceUrl'] as String? ?? '',
    ]);
  }

  Future<void> deleteCatalyst(int rowNumber) => sheets.deleteRow(catalystsTab, rowNumber);

  /// Distinct label names seen across every (non-removed) token row -- there
  /// is no separate Labels table now that the Sheet's own "Labels" column is
  /// the source of truth.
  Future<List<Label>> listLabels() async {
    final all = await _allTokenRows();
    final names = <String>{};
    for (final t in all) {
      if (t.status == 'removed') continue;
      for (final l in t.labels) {
        names.add(l.name);
      }
    }
    final sorted = names.toList()..sort();
    return sorted.map((n) => Label(id: n.hashCode, name: n)).toList();
  }

  /// There's no separate Labels table to delete a row from -- a label only
  /// exists by being listed in some token's "Labels" cell, so deleting one
  /// means removing it from every token that currently has it.
  Future<void> deleteLabelEverywhere(String name) async {
    final all = await _allTokenRows();
    for (final t in all) {
      if (t.labels.any((l) => l.name == name)) {
        final remaining = t.labels.map((l) => l.name).where((n) => n != name).toList();
        await _updateRowFields(t.id, {'labels': remaining});
      }
    }
  }

  /// Refreshes live price/market data for the given tokens (typically the
  /// full active watchlist). Not a background cron -- called on app open and
  /// via the "Refresh now" button, same as the plan's stated Android
  /// constraint. Paced with the same 1.2s-per-token delay the web backend
  /// uses, to stay well inside every free tier's rate limit.
  Future<void> refreshPrices(List<Token> tokens) async {
    final ids = tokens.map((t) => t.coingeckoId).whereType<String>().toList();
    final markets = await cg.fetchCoingeckoMarkets(ids, apiKey: coingeckoApiKey);

    for (final token in tokens) {
      final market = token.coingeckoId != null ? markets[token.coingeckoId] : null;
      final contract = token.deployments.isNotEmpty ? token.deployments.first.contractAddress : null;

      final dexPrice = await dex.fetchDexPrice(contract);
      final binance = await exch.fetchBinanceTicker(token.binanceSymbol);
      final mexc = await exch.fetchMexcTicker(token.mexcSymbol);
      final protocol = await llama.fetchProtocol(token.defillamaSlug);

      final cgPrice = market?.currentPrice;
      final div = gating.divergence([cgPrice, dexPrice?.price, binance?.price, mexc?.price]);
      final volume24h = market?.totalVolume ?? dexPrice?.liquidityUsd;
      final gate = gating.horizonsFor(div, volume24h);
      final quality = gating.dataQualityFor(div);

      final circulating = market?.circulatingSupply;
      final total = market?.totalSupply;
      final marketCap = market?.marketCap;

      _snapshots[token.ticker] = MetricSnapshot(
        id: 0,
        fetchedAt: DateTime.now().toIso8601String(),
        imageUrl: market?.imageUrl,
        priceCoingecko: cgPrice,
        priceDexscreener: dexPrice?.price,
        priceBinance: binance?.price,
        priceMexc: mexc?.price,
        divergencePct: div,
        marketCap: marketCap,
        fdv: market?.fullyDilutedValuation,
        volume24h: volume24h,
        volumeToMcap: (volume24h != null && marketCap != null && marketCap != 0) ? volume24h / marketCap : null,
        change1hPct: market?.change1hPct,
        change24hPct: market?.change24hPct,
        change7dPct: market?.change7dPct,
        change30dPct: market?.change30dPct,
        ath: market?.ath,
        drawdownFromAthPct: market?.athChangePct,
        atl: market?.atl,
        aboveAtlPct: market?.atlChangePct,
        circulatingSupply: circulating,
        totalSupply: total,
        floatPct: (circulating != null && total != null && total != 0) ? (circulating / total) * 100 : null,
        tvl: protocol?.tvl,
        tvlChange30dPct: protocol?.tvlChange30dPct,
        dataQuality: quality,
        assessableHorizons: gate.allowed,
        gatingReason: gate.reason,
      );

      await _sleep(1200);
    }
  }

  /// Convenience for the Dashboard screen's "refresh on open + pull to
  /// refresh" flow: re-fetch live prices for every active token, then build
  /// the summary from the freshly-populated snapshots.
  Future<DashboardSummary> refreshAndGetDashboard() async {
    final tokens = await listTokens(status: 'active');
    await refreshPrices(tokens);
    return getDashboard();
  }

  Future<DashboardSummary> getDashboard() async {
    final tokens = await listTokens(status: 'active');

    final dataQualityCounts = {'Good': 0, 'Degraded': 0, 'Poor': 0, 'Unknown': 0};
    for (final t in tokens) {
      final q = t.latestSnapshot?.dataQuality;
      if (q == 'Good' || q == 'Degraded' || q == 'Poor') {
        dataQualityCounts[q!] = dataQualityCounts[q]! + 1;
      } else {
        dataQualityCounts['Unknown'] = dataQualityCounts['Unknown']! + 1;
      }
    }

    final clusterMap = <String, List<String>>{};
    for (final t in tokens) {
      final key = t.cluster ?? 'Uncategorized';
      (clusterMap[key] ??= []).add(t.ticker);
    }
    final clusterExposure = clusterMap.entries
        .map((e) => ClusterExposure(cluster: e.key, tokenCount: e.value.length, tickers: e.value))
        .toList()
      ..sort((a, b) => b.tokenCount.compareTo(a.tokenCount));

    final now = DateTime.now();
    final upcoming = <UpcomingCatalyst>[];
    for (final t in tokens) {
      final catalysts = await _catalystsFor(t.ticker);
      for (final c in catalysts) {
        final eventDate = DateTime.tryParse(c.eventDate);
        if (eventDate == null) continue;
        final daysUntil = eventDate.difference(now).inDays;
        if (daysUntil < 0 || daysUntil > 90) continue;
        upcoming.add(UpcomingCatalyst(
          id: c.id,
          tokenId: t.id,
          eventDate: c.eventDate,
          eventType: c.eventType,
          description: c.description,
          sizePctOfSupply: c.sizePctOfSupply,
          sourceUrl: c.sourceUrl,
          ticker: t.ticker,
          daysUntil: daysUntil,
        ));
      }
    }
    upcoming.sort((a, b) => a.eventDate.compareTo(b.eventDate));

    final movers = tokens.where((t) => t.latestSnapshot?.change24hPct != null).toList()
      ..sort((a, b) =>
          b.latestSnapshot!.change24hPct!.abs().compareTo(a.latestSnapshot!.change24hPct!.abs()));

    return DashboardSummary(
      generatedAt: now.toIso8601String(),
      tokenCount: tokens.length,
      dataQualityCounts: dataQualityCounts,
      clusterExposure: clusterExposure,
      upcomingCatalysts: upcoming,
      movers: movers.take(5).map((t) => Mover(ticker: t.ticker, tokenId: t.id, change24hPct: t.latestSnapshot?.change24hPct)).toList(),
      tokens: tokens,
    );
  }

  Future<TokenAnalysisResult> getTokenAnalysis(int rowNumber, String interval) async {
    final token = await getToken(rowNumber);
    if (token.coingeckoId == null) {
      return TokenAnalysisResult.unavailable(
        "No CoinGecko id on this token, so there's no historical price series to compute indicators from.",
      );
    }

    final days = candles.intervalFetchDays[interval] ?? 365;
    final outcome = await cg.fetchCoingeckoMarketChart(token.coingeckoId!, days: days, apiKey: coingeckoApiKey);
    if (!outcome.ok) {
      final reason = outcome.reason == FetchFailureReason.rateLimited
          ? "CoinGecko rate-limited this request (the free public tier's limit is low and shared across everyone hitting it). Wait a few seconds and try again -- this isn't a real data gap."
          : "CoinGecko did not return historical data for this token.";
      return TokenAnalysisResult.unavailable(reason);
    }

    final chart = outcome.data!;
    final rawTimestamps = chart.prices.map((p) => p.timestamp).toList();
    final rawCloses = chart.prices.map((p) => p.value).toList();
    final rawVolumes = _alignVolumes(chart.prices, chart.volumes);

    final builtCandles = candles.buildCandles(interval, rawTimestamps, rawCloses, rawVolumes);
    final closes = builtCandles.map((c) => c.close).toList();
    final volumes = builtCandles.map((c) => c.volume).toList();

    if (closes.length < _minCandlesForAnalysis) {
      final reason = interval == '1M'
          ? "Only ${closes.length} monthly candle(s) available -- CoinGecko's free tier caps historical queries at 365 days (~12 months), which isn't enough for MACD/RSI to warm up (need ~$_minCandlesForAnalysis). Try 1w or 1d instead."
          : "Only ${closes.length} candle(s) of history available at $interval -- need at least $_minCandlesForAnalysis for MACD/RSI to mean anything. Try a coarser interval.";
      return TokenAnalysisResult.unavailable(reason);
    }

    final rsi = ind.computeRSI(closes);
    final stochRsi = ind.computeStochasticRSI(closes);
    final macd = ind.computeMACD(closes);
    final obv = ind.computeOBV(closes, volumes);
    final trend = ind.classifyTrend(closes, macd);

    final points = List.generate(builtCandles.length, (i) {
      final c = builtCandles[i];
      return AnalysisPoint(
        timestamp: DateTime.fromMillisecondsSinceEpoch(c.timestamp, isUtc: true).toIso8601String(),
        open: c.open,
        high: c.high,
        low: c.low,
        close: c.close,
        volume: c.volume,
        rsi: rsi[i],
        stochRsiK: stochRsi[i].k,
        stochRsiD: stochRsi[i].d,
        macd: macd[i].macd,
        macdSignal: macd[i].signal,
        macdHistogram: macd[i].histogram,
        obv: obv[i],
      );
    });

    final recentCutoff = closes.length - 14;
    final rsiDiv = ind.detectDivergence(closes, rsi).map((f) => ('RSI', f)).toList();
    final obvDiv = ind.detectDivergence(closes, obv.map((v) => v as double?).toList()).map((f) => ('OBV', f)).toList();
    final divergences = [...rsiDiv, ...obvDiv]
        .where((entry) => entry.$2.toIndex >= recentCutoff)
        .map((entry) => DivergenceFlag(
              indicator: entry.$1,
              type: entry.$2.type,
              fromDate: points[entry.$2.fromIndex].timestamp,
              toDate: points[entry.$2.toIndex].timestamp,
            ))
        .toList();

    final keyLevels = ind
        .findKeyLevels(closes)
        .map((k) => KeyLevel(price: k.price, type: k.type, touches: k.touches))
        .toList();

    final rawChannel = ind.computeTrendChannel(closes);
    final timestamps = builtCandles.map((c) => c.timestamp).toList();
    final spacing = _averageSpacing(timestamps);
    TrendChannel? trendChannel;
    if (rawChannel != null) {
      trendChannel = TrendChannel(
        upper: ChannelLine(
          fromTimestamp: _indexToTimestamp(rawChannel.upper.fromIndex.toDouble(), timestamps, spacing),
          fromPrice: rawChannel.upper.fromPrice,
          toTimestamp: _indexToTimestamp(rawChannel.upper.toIndex, timestamps, spacing),
          toPrice: rawChannel.upper.toPrice,
        ),
        lower: ChannelLine(
          fromTimestamp: _indexToTimestamp(rawChannel.lower.fromIndex.toDouble(), timestamps, spacing),
          fromPrice: rawChannel.lower.fromPrice,
          toTimestamp: _indexToTimestamp(rawChannel.lower.toIndex, timestamps, spacing),
          toPrice: rawChannel.lower.toPrice,
        ),
      );
    }

    return TokenAnalysisResult.fromComputed(
      tokenId: token.id,
      ticker: token.ticker,
      interval: interval,
      points: points,
      divergences: divergences,
      trendState: trend.state,
      trendBasis: trend.basis,
      keyLevels: keyLevels,
      trendChannel: trendChannel,
    );
  }

  Future<TokenInsightResult> getTokenInsight(int rowNumber) async {
    final token = await getToken(rowNumber);
    if (token.coingeckoId == null) {
      return TokenInsightResult.unavailable("No CoinGecko id on this token, so there's no project data to show.");
    }
    final detail = await cg.fetchCoingeckoCoinDetail(token.coingeckoId!, apiKey: coingeckoApiKey);
    if (detail == null) {
      return TokenInsightResult.unavailable(
        "CoinGecko did not return project details for this token (may be rate-limited -- try again shortly).",
      );
    }
    _categoryCache[token.ticker] = simplifyCategories(detail.categories);
    return TokenInsightResult.fromComputed(
      description: detail.description?.trim().isEmpty == true ? null : detail.description,
      categories: detail.categories,
      genesisDate: detail.genesisDate,
      marketCapRank: detail.marketCapRank,
      sentimentUpPct: detail.sentimentUpPct,
      sentimentDownPct: detail.sentimentDownPct,
      links: TokenInsightLinks(
        homepage: detail.homepage,
        twitter: detail.twitterScreenName != null && detail.twitterScreenName!.isNotEmpty
            ? 'https://twitter.com/${detail.twitterScreenName}'
            : null,
        telegram: detail.telegramChannel != null && detail.telegramChannel!.isNotEmpty
            ? 'https://t.me/${detail.telegramChannel}'
            : null,
        subreddit: detail.subredditUrl,
        github: detail.githubRepos,
        chat: detail.chatUrls,
      ),
      watchlistPortfolioUsers: detail.watchlistPortfolioUsers,
      redditSubscribers: detail.redditSubscribers,
      telegramUserCount: detail.telegramUserCount,
      redditAveragePosts48h: detail.redditAveragePosts48h,
      redditAverageComments48h: detail.redditAverageComments48h,
      redditAccountsActive48h: detail.redditAccountsActive48h,
      stars: detail.stars,
      forks: detail.forks,
      contributors: detail.pullRequestContributors,
      commitCount4Weeks: detail.commitCount4Weeks,
    );
  }

  Future<List<cg.CoingeckoSearchResult>> searchCoingecko(String query) => cg.searchCoingecko(query);
}

List<double> _alignVolumes(List<cg.MarketChartPoint> prices, List<cg.MarketChartPoint> volumes) {
  if (prices.length == volumes.length) return volumes.map((v) => v.value).toList();
  return prices.map((p) {
    var closest = volumes.isNotEmpty ? volumes.first.value : 0.0;
    var bestDelta = double.infinity;
    for (final v in volumes) {
      final delta = (v.timestamp - p.timestamp).abs().toDouble();
      if (delta < bestDelta) {
        bestDelta = delta;
        closest = v.value;
      }
    }
    return closest;
  }).toList();
}

double _averageSpacing(List<int> timestamps) {
  if (timestamps.length < 2) return 0;
  var total = 0;
  for (var i = 1; i < timestamps.length; i++) {
    total += timestamps[i] - timestamps[i - 1];
  }
  return total / (timestamps.length - 1);
}

String _indexToTimestamp(double index, List<int> timestamps, double spacing) {
  if (index < timestamps.length) {
    return DateTime.fromMillisecondsSinceEpoch(timestamps[index.round()], isUtc: true).toIso8601String();
  }
  final overshoot = index - (timestamps.length - 1);
  final ms = timestamps.last + (overshoot * spacing).round();
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
}
