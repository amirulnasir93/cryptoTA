// Ported from packages/backend/src/knownCollisions.ts (itself hardcoded from
// Skills/data-sources.md's "Known traps on the current list" section).

const Map<String, String> knownTickerCollisions = {
  'BASED':
      'Coinbase lists this asset as BASED1, not BASED. Two unrelated micro-cap tokens on Base also use the BASED ticker (coingecko ids based-2, based-coin) and are effectively illiquid. Verify chain + contract before trusting a feed.',
  'GENIUS':
      'Distinct from Genius (GENI) on Polygon and Genius Token (GNUS). Verify the CoinGecko id resolves to genius-3.',
  'APEX': 'Ticker collides with other, unrelated APEX tokens. Match on chain and contract before trusting a feed.',
  'ZEST': 'Ticker collides with other, unrelated ZEST tokens. Match on chain and contract before trusting a feed.',
  'UAI': 'Ticker collides with other, unrelated UAI tokens. Match on chain and contract before trusting a feed.',
};

String? collisionWarningFor(String ticker) => knownTickerCollisions[ticker.toUpperCase()];
