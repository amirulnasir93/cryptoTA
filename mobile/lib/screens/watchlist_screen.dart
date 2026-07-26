import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repository.dart';
import '../connectors/coingecko.dart' show CoingeckoSearchResult;
import '../models.dart';
import '../widgets/common.dart';
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
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
        child: const Icon(Icons.add),
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
            return Center(child: Text('No $_status tokens.', style: TextStyle(color: Theme.of(context).hintColor)));
          }
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView.separated(
              itemCount: tokens.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = tokens[i];
                final s = t.latestSnapshot;
                return ListTile(
                  title: Text(t.ticker, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([t.projectName, t.primaryChain].where((v) => v != null && v.isNotEmpty).join(' · ')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DeltaText(value: s?.change24hPct),
                      PopupMenuButton<String>(
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
  final _chain = TextEditingController();
  final _coingeckoQuery = TextEditingController();
  final _cluster = TextEditingController();
  CoingeckoSearchResult? _selectedCoin;
  List<CoingeckoSearchResult> _suggestions = [];
  Timer? _debounce;
  bool _saving = false;
  String? _error;

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
        if (_chain.text.trim().isNotEmpty) 'primaryChain': _chain.text.trim(),
        if (_selectedCoin != null) 'coingeckoId': _selectedCoin!.id,
        if (_cluster.text.trim().isNotEmpty) 'cluster': _cluster.text.trim(),
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
              const SizedBox(height: 8),
              TextField(controller: _projectName, decoration: const InputDecoration(labelText: 'Project name')),
              const SizedBox(height: 8),
              TextField(controller: _chain, decoration: const InputDecoration(labelText: 'Primary chain')),
              const SizedBox(height: 8),
              TextField(
                controller: _coingeckoQuery,
                decoration: const InputDecoration(labelText: 'CoinGecko search'),
                onChanged: _onCoingeckoQueryChanged,
              ),
              if (_selectedCoin != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Chip(label: Text('Selected: ${_selectedCoin!.name} (${_selectedCoin!.id})')),
                ),
              if (_suggestions.isNotEmpty)
                ConstrainedBox(
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
              const SizedBox(height: 8),
              TextField(controller: _cluster, decoration: const InputDecoration(labelText: 'Cluster')),
              if (_error != null) ...[
                const SizedBox(height: 8),
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
