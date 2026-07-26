// Maps CoinGecko's raw category strings (e.g. "Decentralized Finance (DeFi)",
// "Perpetuals") down to one short badge -- a simplification for list rows,
// not a replacement for the full category list already shown on the Insight
// tab. Checked in priority order (most specific first) since a token
// commonly has several overlapping categories and the broad ones ("DeFi")
// would otherwise always win over a more useful specific one ("Perp").
const _priority = <(String, String)>[
  ('perpetual', 'Perp'),
  ('derivative', 'Derivatives'),
  ('decentralized exchange', 'DEX'),
  ('dex', 'DEX'),
  ('lending', 'Lending'),
  ('borrowing', 'Lending'),
  ('stablecoin', 'Stablecoin'),
  ('real world asset', 'RWA'),
  ('liquid staking', 'LSD'),
  ('oracle', 'Oracle'),
  ('nft', 'NFT'),
  ('gaming', 'Gaming'),
  ('gamefi', 'Gaming'),
  ('metaverse', 'Metaverse'),
  ('artificial intelligence', 'AI'),
  ('meme', 'Meme'),
  ('privacy', 'Privacy'),
  ('layer 2', 'L2'),
  ('layer 1', 'L1'),
  ('smart contract platform', 'L1'),
  ('yield', 'Yield'),
  ('decentralized finance', 'DeFi'),
  ('defi', 'DeFi'),
  ('infrastructure', 'Infra'),
];

String? simplifyCategories(List<String> categories) {
  final lower = categories.map((c) => c.toLowerCase()).toList();
  for (final (keyword, label) in _priority) {
    if (lower.any((c) => c.contains(keyword))) return label;
  }
  return null;
}
