import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repository.dart';
import '../connectors/coingecko.dart' show CoingeckoSearchResult;
import '../constants.dart';
import '../models.dart';
import '../widgets/common.dart';
import '../widgets/searchable_field.dart';
import 'token_detail_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  String _status = 'active';
  late Future<List<Token>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppRepository>().listTokens(status: _status);
  }

  void _reload() {
    setState(() => _future = context.read<AppRepository>().listTokens(status: _status));
  }

  void _setStatus(String status) {
    setState(() {
      _status = status;
      _future = context.read<AppRepository>().listTokens(status: status);
    });
  }

  Future<void> _archive(Token t) async {
    await context.read<AppRepository>().archiveToken(t.id);
    _reload();
  }

  Future<void> _restore(Token t) async {
    await context.read<AppRepository>().restoreToken(t.id);
    _reload();
  }

  Future<void> _remove(Token t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${t.ticker}?'),
        content: const Text('This permanently deletes the token and its history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AppRepository>().removeToken(t.id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'active', label: Text('Active')),
                ButtonSegment(value: 'archived', label: Text('Archived')),
              ],
              selected: {_status},
              onSelectionChanged: (s) => _setStatus(s.first),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await showDialog<bool>(context: context, builder: (_) => const AddTokenDialog());
          if (created == true) _reload();
        },
        child: const Icon(Icons.add_rounded),
      ),
      body: FutureBuilder<List<Token>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorRetry(message: 'Could not load watchlist: ${snapshot.error}', onRetry: _reload);
          }
          final tokens = snapshot.data!;
          if (tokens.isEmpty) {
            return Center(
              child: Text('No $_status tokens.', style: TextStyle(color: scheme.onSurfaceVariant)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: tokens.length,
              itemBuilder: (context, i) {
                final t = tokens[i];
                final s = t.latestSnapshot;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: TickerAvatar(ticker: t.ticker, imageUrl: s?.imageUrl),
                      title: Text(t.ticker, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([t.projectName, t.primaryChain].where((v) => v != null && v.isNotEmpty).join(' · ')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DeltaText(value: s?.change24hPct),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
                            onSelected: (action) {
                              switch (action) {
                                case 'archive':
                                  _archive(t);
                                  break;
                                case 'restore':
                                  _restore(t);
                                  break;
                                case 'remove':
                                  _remove(t);
                                  break;
                              }
                            },
                            itemBuilder: (_) => [
                              if (t.status == 'active') const PopupMenuItem(value: 'archive', child: Text('Archive')),
                              if (t.status == 'archived') const PopupMenuItem(value: 'restore', child: Text('Restore')),
                              const PopupMenuItem(value: 'remove', child: Text('Remove')),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TokenDetailScreen(tokenId: t.id))),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class AddTokenDialog extends StatefulWidget {
  const AddTokenDialog({super.key});

  @override
  State<AddTokenDialog> createState() => _AddTokenDialogState();
}

class _AddTokenDialogState extends State<AddTokenDialog> {
  final _ticker = TextEditingController();
  final _projectName = TextEditingController();
  final _coingeckoQuery = TextEditingController();
  String _chain = '';
  String _cluster = '';
  List<String> _clusterOptions = [];
  CoingeckoSearchResult? _selectedCoin;
  List<CoingeckoSearchResult> _suggestions = [];
  Timer? _debounce;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    context.read<AppRepository>().listTokens(status: 'all').then((tokens) {
      if (!mounted) return;
      final clusters = tokens.map((t) => t.cluster).whereType<String>().where((c) => c.isNotEmpty).toSet().toList()
        ..sort();
      setState(() => _clusterOptions = clusters);
    });
  }

  void _onCoingeckoQueryChanged(String value) {
    _debounce?.cancel();
    _selectedCoin = null;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final api = context.read<AppRepository>();
      final results = await api.searchCoingecko(value);
      if (mounted) setState(() => _suggestions = results);
    });
  }

  Future<void> _submit() async {
    if (_ticker.text.trim().isEmpty) {
      setState(() => _error = 'Ticker is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = context.read<AppRepository>();
      await api.createToken({
        'ticker': _ticker.text.trim().toUpperCase(),
        if (_projectName.text.trim().isNotEmpty) 'projectName': _projectName.text.trim(),
        if (_chain.trim().isNotEmpty) 'primaryChain': _chain.trim(),
        if (_selectedCoin != null) 'coingeckoId': _selectedCoin!.id,
        if (_cluster.trim().isNotEmpty) 'cluster': _cluster.trim(),
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
      title: const Text('Add token'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _ticker, decoration: const InputDecoration(labelText: 'Ticker *')),
              const SizedBox(height: 10),
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
                decoration: const InputDecoration(labelText: 'CoinGecko search'),
                onChanged: _onCoingeckoQueryChanged,
              ),
              if (_selectedCoin != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Chip(
                    avatar: const Icon(Icons.check_circle_rounded, size: 16),
                    label: Text('${_selectedCoin!.name} (${_selectedCoin!.id})'),
                  ),
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
                                _selectedCoin = s;
                                _suggestions = [];
                                _coingeckoQuery.text = s.name;
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
        FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Saving…' : 'Add')),
      ],
    );
  }
}
