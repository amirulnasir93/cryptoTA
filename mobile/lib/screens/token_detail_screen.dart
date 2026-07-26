import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repository.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'insight_tab.dart';
import 'technical_analysis_tab.dart';

class TokenDetailScreen extends StatefulWidget {
  final int tokenId;
  const TokenDetailScreen({super.key, required this.tokenId});

  @override
  State<TokenDetailScreen> createState() => _TokenDetailScreenState();
}

class _TokenDetailScreenState extends State<TokenDetailScreen> {
  late Future<TokenDetail> _tokenFuture;
  late Future<List<Label>> _labelsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _tokenFuture = context.read<AppRepository>().getToken(widget.tokenId);
    _labelsFuture = context.read<AppRepository>().listLabels();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: FutureBuilder<TokenDetail>(
            future: _tokenFuture,
            builder: (context, snapshot) => Text(snapshot.data?.ticker ?? '…'),
          ),
          bottom: const TabBar(
            tabs: [Tab(text: 'Overview'), Tab(text: 'Technical'), Tab(text: 'Insight')],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(
              tokenFuture: _tokenFuture,
              labelsFuture: _labelsFuture,
              onChanged: () => setState(_load),
            ),
            TechnicalAnalysisTab(tokenId: widget.tokenId),
            InsightTab(tokenId: widget.tokenId),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatefulWidget {
  final Future<TokenDetail> tokenFuture;
  final Future<List<Label>> labelsFuture;
  final VoidCallback onChanged;

  const _OverviewTab({required this.tokenFuture, required this.labelsFuture, required this.onChanged});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final _notesController = TextEditingController();
  final _newLabelController = TextEditingController();
  int? _notesLoadedForToken;

  Future<void> _toggleLabel(TokenDetail token, Label label) async {
    final has = token.labels.any((l) => l.name == label.name);
    final names = token.labels.map((l) => l.name).toList();
    final next = has ? (names..remove(label.name)) : [...names, label.name];
    await context.read<AppRepository>().updateToken(token.id, {'labels': next});
    widget.onChanged();
  }

  Future<void> _addNewLabel(TokenDetail token) async {
    final name = _newLabelController.text.trim();
    if (name.isEmpty) return;
    final names = token.labels.map((l) => l.name).toList();
    if (!names.contains(name)) names.add(name);
    await context.read<AppRepository>().updateToken(token.id, {'labels': names});
    _newLabelController.clear();
    widget.onChanged();
  }

  Future<void> _saveNotes(TokenDetail token) async {
    await context.read<AppRepository>().updateToken(token.id, {'notes': _notesController.text});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TokenDetail>(
      future: widget.tokenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorRetry(message: '${snapshot.error}', onRetry: widget.onChanged);
        }
        final token = snapshot.data!;
        final s = token.latestSnapshot;

        if (_notesLoadedForToken != token.id) {
          _notesController.text = token.notes ?? '';
          _notesLoadedForToken = token.id;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Text(token.projectName ?? '', style: TextStyle(color: Theme.of(context).hintColor)),
                const Spacer(),
                DataQualityBadge(quality: s?.dataQuality),
              ],
            ),
            Text(
              [token.primaryChain, token.cluster].where((v) => v != null && v.isNotEmpty).join(' · '),
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
            ),
            if (token.collisionWarning != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(6)),
                child: Text('⚠ ${token.collisionWarning}', style: const TextStyle(color: Colors.orange)),
              ),
            ],
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                StatTile(label: 'Price', value: Text(s?.priceCoingecko != null ? '\$${s!.priceCoingecko}' : '—')),
                StatTile(label: '24h', value: DeltaText(value: s?.change24hPct)),
                StatTile(label: '7d', value: DeltaText(value: s?.change7dPct)),
                StatTile(label: '30d', value: DeltaText(value: s?.change30dPct)),
                StatTile(label: 'Market cap', value: Text(formatUsd(s?.marketCap))),
                StatTile(label: 'FDV', value: Text(formatUsd(s?.fdv))),
                StatTile(label: '24h volume', value: Text(formatUsd(s?.volume24h))),
                StatTile(label: 'ATH drawdown', value: Text(s?.drawdownFromAthPct != null ? '${s!.drawdownFromAthPct!.toStringAsFixed(1)}%' : '—')),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Per-source price', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(s?.gatingReason ?? 'No snapshot yet — run a refresh.', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _SourcePrice(label: 'CoinGecko', value: s?.priceCoingecko),
                _SourcePrice(label: 'DexScreener', value: s?.priceDexscreener),
                _SourcePrice(label: 'Binance', value: s?.priceBinance),
                _SourcePrice(label: 'MEXC', value: s?.priceMexc),
              ],
            ),
            if (token.clusterSiblings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Cluster: ${token.cluster}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...token.clusterSiblings.map(
                (sib) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [Text(sib.ticker), const SizedBox(width: 8), DeltaText(value: sib.latestSnapshot?.change24hPct)]),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text('Labels', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<List<Label>>(
              future: widget.labelsFuture,
              builder: (context, labelSnapshot) {
                final labels = labelSnapshot.data ?? [];
                if (labels.isEmpty) return Text('No labels yet.', style: TextStyle(color: Theme.of(context).hintColor));
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: labels.map((l) {
                    final active = token.labels.any((tl) => tl.name == l.name);
                    return FilterChip(label: Text(l.name), selected: active, onSelected: (_) => _toggleLabel(token, l));
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newLabelController,
                    decoration: const InputDecoration(labelText: 'New label', isDense: true, border: OutlineInputBorder()),
                    onSubmitted: (_) => _addNewLabel(token),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: () => _addNewLabel(token), child: const Text('Add')),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onSubmitted: (_) => _saveNotes(token),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => _saveNotes(token), child: const Text('Save notes')),
            ),
            const SizedBox(height: 8),
            _CatalystSection(token: token, onChanged: widget.onChanged),
          ],
        );
      },
    );
  }
}

class _SourcePrice extends StatelessWidget {
  final String label;
  final double? value;
  const _SourcePrice({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        Text(value != null ? '\$$value' : '—'),
      ],
    );
  }
}

class _CatalystSection extends StatefulWidget {
  final TokenDetail token;
  final VoidCallback onChanged;
  const _CatalystSection({required this.token, required this.onChanged});

  @override
  State<_CatalystSection> createState() => _CatalystSectionState();
}

class _CatalystSectionState extends State<_CatalystSection> {
  final _descriptionController = TextEditingController();
  DateTime? _date;
  String _type = 'unlock';

  Future<void> _add() async {
    if (_date == null || _descriptionController.text.trim().isEmpty) return;
    await context.read<AppRepository>().createCatalyst({
      'ticker': widget.token.ticker,
      'eventDate': _date!.toIso8601String(),
      'eventType': _type,
      'description': _descriptionController.text.trim(),
    });
    _descriptionController.clear();
    setState(() => _date = null);
    widget.onChanged();
  }

  Future<void> _delete(Catalyst c) async {
    await context.read<AppRepository>().deleteCatalyst(c.id);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Catalysts', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (widget.token.catalysts.isEmpty)
          Text('None recorded.', style: TextStyle(color: Theme.of(context).hintColor))
        else
          ...widget.token.catalysts.map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.description),
              subtitle: Text('${DateTime.parse(c.eventDate).toLocal().toString().split(' ').first} · ${c.eventType}'),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(c)),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2015),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: Text(_date == null ? 'Pick date' : _date!.toString().split(' ').first),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _type,
              items: const [
                DropdownMenuItem(value: 'unlock', child: Text('Unlock')),
                DropdownMenuItem(value: 'listing', child: Text('Listing')),
                DropdownMenuItem(value: 'governance', child: Text('Governance')),
                DropdownMenuItem(value: 'launch', child: Text('Launch')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'unlock'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _add, child: const Text('Add catalyst'))),
      ],
    );
  }
}
