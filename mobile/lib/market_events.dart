// Mirrors packages/shared/src/marketEvents.ts's pure matching logic --
// ticker AND project-name-fragment match are both required (collision
// safety; see that file's history for the AERO/"Ethereum Mainnet Launch"
// false-match incident this rule exists to prevent).
import 'connectors/coinmarketcal.dart';

enum MarketEventType { unlock, listing, governance, launch, other }

String marketEventTypeLabel(MarketEventType t) {
  switch (t) {
    case MarketEventType.unlock:
      return 'unlock';
    case MarketEventType.listing:
      return 'listing';
    case MarketEventType.governance:
      return 'governance';
    case MarketEventType.launch:
      return 'launch';
    case MarketEventType.other:
      return 'other';
  }
}

const _categoryToEventType = [
  (patterns: ['unlock', 'vesting', 'cliff'], eventType: MarketEventType.unlock),
  (patterns: ['listing', 'exchange'], eventType: MarketEventType.listing),
  (patterns: ['governance', 'vote', 'proposal'], eventType: MarketEventType.governance),
  (patterns: ['mainnet', 'launch', 'upgrade', 'fork', 'release'], eventType: MarketEventType.launch),
];

MarketEventType classifyEventType(CoinMarketCalEvent event) {
  final title = event.eventTitle.toLowerCase();
  for (final entry in _categoryToEventType) {
    final matches = event.categoryNames.any((c) => entry.patterns.any((p) => c.contains(p))) ||
        entry.patterns.any((p) => title.contains(p));
    if (matches) return entry.eventType;
  }
  return MarketEventType.other;
}

String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

class MarketEvent {
  final String ticker;
  final String description;
  final DateTime eventDate;
  final MarketEventType eventType;
  final String? sourceUrl;
  final int daysUntil;

  MarketEvent({
    required this.ticker,
    required this.description,
    required this.eventDate,
    required this.eventType,
    required this.sourceUrl,
    required this.daysUntil,
  });
}

class WatchlistTokenRef {
  final String ticker;
  final String? projectName;
  WatchlistTokenRef({required this.ticker, required this.projectName});
}

List<MarketEvent> matchWatchlistEvents(
  List<CoinMarketCalEvent> events,
  List<WatchlistTokenRef> tokens, {
  int daysAhead = 90,
}) {
  final now = DateTime.now();
  final out = <MarketEvent>[];
  for (final event in events) {
    final description = event.eventTitle;
    final eventDate = DateTime.tryParse(event.date);
    if (eventDate == null) continue;
    final daysUntil = eventDate.difference(now).inDays;
    if (daysUntil < 0 || daysUntil > daysAhead) continue;
    for (final coin in event.coins) {
      final symbol = coin.symbol.toUpperCase();
      final matchingTokens = tokens.where((t) => t.ticker == symbol);
      for (final token in matchingTokens) {
        final projectFragment =
            token.projectName != null && token.projectName!.isNotEmpty ? _normalize(token.projectName!).substring(0, _normalize(token.projectName!).length.clamp(0, 6)) : '';
        final nameMatches = projectFragment.isNotEmpty && _normalize(coin.name).contains(projectFragment);
        if (!nameMatches) continue;
        out.add(MarketEvent(
          ticker: token.ticker,
          description: description,
          eventDate: eventDate,
          eventType: classifyEventType(event),
          sourceUrl: event.sourceUrl,
          daysUntil: daysUntil,
        ));
      }
    }
  }
  out.sort((a, b) => a.eventDate.compareTo(b.eventDate));
  return out;
}
