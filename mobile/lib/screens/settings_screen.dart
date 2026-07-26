import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../api_client.dart';
import '../models.dart';

class SettingsScreen extends StatefulWidget {
  final bool firstRun;
  const SettingsScreen({super.key, required this.firstRun});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _secretController;
  String? _status;
  bool _busy = false;
  List<ConflictLogEntry> _conflicts = [];

  @override
  void initState() {
    super.initState();
    final config = context.read<AppConfig>();
    _urlController = TextEditingController(text: config.baseUrl ?? 'http://10.0.2.2:3001');
    _secretController = TextEditingController(text: config.refreshSecret ?? '');
    if (!widget.firstRun) _loadConflicts();
  }

  Future<void> _loadConflicts() async {
    try {
      final api = context.read<ApiClient>();
      final conflicts = await api.listConflicts();
      if (mounted) setState(() => _conflicts = conflicts);
    } catch (_) {
      // Conflict log is a nice-to-have on this screen -- don't block Settings
      // from rendering if it fails to load.
    }
  }

  Future<void> _saveUrl() async {
    await context.read<AppConfig>().setBaseUrl(_urlController.text);
    setState(() => _status = 'Saved. Base URL: ${_urlController.text}');
  }

  Future<void> _saveSecret() async {
    await context.read<AppConfig>().setRefreshSecret(_secretController.text);
    setState(() => _status = 'Refresh secret saved.');
  }

  Future<void> _runAction(Future<Map<String, dynamic>> Function(String secret) action, String label) async {
    final secret = context.read<AppConfig>().refreshSecret;
    if (secret == null || secret.isEmpty) {
      setState(() => _status = 'Set the refresh secret first.');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Running $label…';
    });
    try {
      final result = await action(secret);
      setState(() => _status = '$label done: $result');
      _loadConflicts();
    } catch (e) {
      setState(() => _status = '$label failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.firstRun) ...[
          const Text('Welcome', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Point the app at your backend before continuing. An Android emulator reaches your '
            "computer's localhost at 10.0.2.2; a physical phone needs your computer's LAN IP "
            '(e.g. http://192.168.1.20:3001) with both devices on the same network.',
          ),
          const SizedBox(height: 16),
        ],
        const Text('Backend URL', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'http://10.0.2.2:3001'),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _saveUrl, child: const Text('Save URL')),
        const SizedBox(height: 24),
        const Text('Refresh secret', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Same shared secret as the web app\'s Settings page -- protects /refresh and /sync routes.',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _secretController,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          obscureText: true,
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _saveSecret, child: const Text('Save secret')),
        if (!widget.firstRun) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          const Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : () => _runAction((s) => context.read<ApiClient>().runRefresh(s), 'Refresh'),
                child: const Text('Run refresh'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _runAction((s) => context.read<ApiClient>().runSheetSync(s), 'Sheets sync'),
                child: const Text('Run Sheets sync'),
              ),
              OutlinedButton(
                onPressed:
                    _busy ? null : () => _runAction((s) => context.read<ApiClient>().syncCoinMarketCal(s), 'Catalyst sync'),
                child: const Text('Sync catalysts'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Conflict log', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_conflicts.isEmpty)
            Text('None recorded.', style: TextStyle(color: Theme.of(context).hintColor))
          else
            ..._conflicts.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${c.ticker} · ${c.field} · resolved: ${c.resolution.replaceAll('_', ' ')}'),
              ),
            ),
        ],
        if (_status != null) ...[
          const SizedBox(height: 16),
          Text(_status!, style: TextStyle(color: Theme.of(context).hintColor)),
        ],
      ],
    );

    if (widget.firstRun) {
      return Scaffold(appBar: AppBar(title: const Text('Setup')), body: SafeArea(child: body));
    }
    return Scaffold(appBar: AppBar(title: const Text('Settings')), body: body);
  }
}
