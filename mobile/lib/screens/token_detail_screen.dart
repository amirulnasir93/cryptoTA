import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repository.dart';
import '../connectors/coingecko.dart' show CoingeckoSearchResult;
import '../constants.dart';
import '../models.dart';
import '../widgets/common.dart';
import '../widgets/searchable_field.dart';
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

  Future<void> _openEdit() async {
    final token = await _tokenFuture;
    if (!mounted) return;
    final changed = await showDialog<bool>(context: context, builder: (_) => EditTokenDialog(token: token));
    if (changed == true) setState(_load);
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
          actions: [
            IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit token', onPressed: _openEdit),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Overview'), Tab(text: 'Technical'), Tab(text: 'Insight')],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
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
    final scheme = Theme.of(context).colorScheme;
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
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomSafePadding(context)),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TickerAvatar(ticker: token.ticker, imageUrl: s?.imageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(token.projectName ?? token.ticker, style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        [token.primaryChain, token.cluster].where((v) => v != null && v.isNotEmpty).join(' · '),
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                DataQualityBadge(quality: s?.dataQuality),
              ],
            ),
            if (token.collisionWarning != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: warningColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: warningColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(token.collisionWarning!, style: TextStyle(color: warningColor, fontSize: 12.5))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.1,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                StatTile(label: 'Price', icon: Icons.paid_outlined, value: Text(s?.priceCoingecko != null ? '\$${s!.priceCoingecko}' : '—')),
                StatTile(label: '1h', icon: Icons.hourglass_bottom_rounded, value: DeltaText(value: s?.change1hPct)),
                StatTile(label: '24h', icon: Icons.schedule_rounded, value: DeltaText(value: s?.change24hPct)),
                StatTile(label: '7d', icon: Icons.calendar_view_week_rounded, value: DeltaText(value: s?.change7dPct)),
                StatTile(label: '30d', icon: Icons.calendar_month_rounded, value: DeltaText(value: s?.change30dPct)),
                StatTile(label: 'Market cap', icon: Icons.account_balance_rounded, value: Text(formatUsd(s?.marketCap))),
                StatTile(label: 'FDV', icon: Icons.pie_chart_outline_rounded, value: Text(formatUsd(s?.fdv))),
                StatTile(label: '24h volume', icon: Icons.bar_chart_rounded, value: Text(formatUsd(s?.volume24h))),
                StatTile(
                  label: 'ATH drawdown',
                  icon: Icons.trending_down_rounded,
                  value: Text(s?.drawdownFromAthPct != null ? '${s!.drawdownFromAthPct!.toStringAsFixed(1)}%' : '—'),
                ),
                StatTile(
                  label: 'Above ATL',
                  icon: Icons.trending_up_rounded,
                  value: Text(s?.aboveAtlPct != null ? '${s!.aboveAtlPct!.toStringAsFixed(1)}%' : '—'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Per-source price'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s?.gatingReason ?? 'No snapshot yet — run a refresh.',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    children: [
                      _SourcePrice(label: 'CoinGecko', value: s?.priceCoingecko),
                      _SourcePrice(label: 'DexScreener', value: s?.priceDexscreener),
                      _SourcePrice(label: 'Binance', value: s?.priceBinance),
                      _SourcePrice(label: 'MEXC', value: s?.priceMexc),
                    ],
                  ),
                  if (s?.assessableHorizons.isNotEmpty ?? false) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: s!.assessableHorizons
                          .map((h) => Chip(label: Text(h.replaceAll('_', ' '), style: const TextStyle(fontSize: 11))))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            if (token.clusterSiblings.isNotEmpty) ...[
              const SizedBox(height: 20),
              SectionHeader(title: 'Cluster: ${token.cluster}', subtitle: "These tokens don't move independently."),
              AppCard(
                child: Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  children: token.clusterSiblings
                      .map((sib) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(sib.ticker, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(width: 6),
                              DeltaText(value: sib.latestSnapshot?.change24hPct, fontSize: 12),
                            ],
                          ))
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const SectionHeader(title: 'Labels'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<List<Label>>(
                    future: widget.labelsFuture,
                    builder: (context, labelSnapshot) {
                      final labels = labelSnapshot.data ?? [];
                      if (labels.isEmpty) {
                        return Text('No labels yet.', style: TextStyle(color: scheme.onSurfaceVariant));
                      }
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newLabelController,
                          decoration: const InputDecoration(labelText: 'New label', isDense: true),
                          onSubmitted: (_) => _addNewLabel(token),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(icon: const Icon(Icons.add_rounded), onPressed: () => _addNewLabel(token)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Notes'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Add a note…'),
                    onSubmitted: (_) => _saveNotes(token),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => _saveNotes(token), child: const Text('Save notes')),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Catalysts'),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value != null ? '\$$value' : '—', style: const TextStyle(fontWeight: FontWeight.w700)),
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
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.token.catalysts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('None recorded.', style: TextStyle(color: scheme.onSurfaceVariant)),
            )
          else
            ...widget.token.catalysts.map(
              (c) => ListTile(
                title: Text(c.description),
                subtitle: Text('${DateTime.parse(c.eventDate).toLocal().toString().split(' ').first} · ${c.eventType}'),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: scheme.onSurfaceVariant),
                  onPressed: () => _delete(c),
                ),
              ),
            ),
          const Divider(height: 24, indent: 12, endIndent: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2015),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => _date = picked);
                        },
                        label: Text(_date == null ? 'Pick date' : _date!.toString().split(' ').first),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _type,
                      underline: const SizedBox.shrink(),
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
                const SizedBox(height: 10),
                TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _add, child: const Text('Add catalyst'))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Editing project name/chain/CoinGecko id/cluster -- notes and labels have
/// their own inline editors on the Overview tab already, so this only covers
/// the fields that had no editing path at all on mobile before.
class EditTokenDialog extends StatefulWidget {
  final TokenDetail token;
  const EditTokenDialog({super.key, required this.token});

  @override
  State<EditTokenDialog> createState() => _EditTokenDialogState();
}

class _EditTokenDialogState extends State<EditTokenDialog> {
  late final _projectName = TextEditingController(text: widget.token.projectName ?? '');
  late final _coingeckoQuery = TextEditingController(text: widget.token.coingeckoId ?? '');
  late String _chain = widget.token.primaryChain ?? '';
  late String _cluster = widget.token.cluster ?? '';
  List<String> _clusterOptions = [];
  String? _coingeckoId;
  List<CoingeckoSearchResult> _suggestions = [];
  Timer? _debounce;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _coingeckoId = widget.token.coingeckoId;
    context.read<AppRepository>().listTokens(status: 'all').then((tokens) {
      if (!mounted) return;
      final clusters = tokens.map((t) => t.cluster).whereType<String>().where((c) => c.isNotEmpty).toSet().toList()
        ..sort();
      setState(() => _clusterOptions = clusters);
    });
  }

  void _onCoingeckoQueryChanged(String value) {
    _debounce?.cancel();
    _coingeckoId = null;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final api = context.read<AppRepository>();
      final results = await api.searchCoingecko(value);
      if (mounted) setState(() => _suggestions = results);
    });
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AppRepository>().updateToken(widget.token.id, {
        'projectName': _projectName.text.trim().isEmpty ? null : _projectName.text.trim(),
        'primaryChain': _chain.trim().isEmpty ? null : _chain.trim(),
        'coingeckoId': _coingeckoId ?? (_coingeckoQuery.text.trim().isEmpty ? null : _coingeckoQuery.text.trim()),
        'cluster': _cluster.trim().isEmpty ? null : _cluster.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = '$e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.token.ticker}'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _projectName, decoration: const InputDecoration(labelText: 'Project name')),
              const SizedBox(height: 10),
              SearchableField(
                label: 'Primary chain',
                initialValue: _chain,
                options: commonChains,
                onChanged: (v) => _chain = v,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _coingeckoQuery,
                decoration: const InputDecoration(labelText: 'CoinGecko ID / search'),
                onChanged: _onCoingeckoQueryChanged,
              ),
              if (_suggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListView(
                      shrinkWrap: true,
                      children: _suggestions
                          .map(
                            (s) => ListTile(
                              dense: true,
                              title: Text('${s.name} (${s.symbol.toUpperCase()})'),
                              subtitle: Text(s.id),
                              onTap: () => setState(() {
                                _coingeckoId = s.id;
                                _suggestions = [];
                                _coingeckoQuery.text = s.id;
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              SearchableField(
                label: 'Cluster',
                initialValue: _cluster,
                options: _clusterOptions,
                onChanged: (v) => _cluster = v,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: downColor)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Saving…' : 'Save')),
      ],
    );
  }
}
