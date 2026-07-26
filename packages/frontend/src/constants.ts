// A static list is fine here: it's just suggestions to reduce typos/drift
// (e.g. "BNB Chain" vs "BSC" ending up as two different cluster/chain
// strings) -- typing anything else is still allowed by SearchableSelect,
// unlike a native <select>. Shared between the Add and Edit token forms.
export const COMMON_CHAINS = [
  "Ethereum",
  "Bitcoin",
  "BNB Chain",
  "Base",
  "Arbitrum One",
  "Optimism",
  "Polygon",
  "Avalanche",
  "Solana",
  "TON",
  "Stacks",
  "Tron",
  "Hyperliquid",
  "multichain",
];
