import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../google_auth.dart';

class SettingsScreen extends StatefulWidget {
  final bool firstRun;
  final VoidCallback? onConfigured;
  const SettingsScreen({super.key, required this.firstRun, this.onConfigured});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _serverClientIdController;
  late final TextEditingController _sheetIdController;
  late final TextEditingController _coingeckoController;
  String? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<AppConfig>();
    _serverClientIdController = TextEditingController(text: config.serverClientId ?? '');
    _sheetIdController = TextEditingController(text: config.sheetId ?? '');
    _coingeckoController = TextEditingController(text: config.coingeckoApiKey ?? '');
  }

  Future<void> _saveServerClientId() async {
    await context.read<AppConfig>().setServerClientId(_serverClientIdController.text);
    setState(() => _status = 'Web Client ID saved.');
    widget.onConfigured?.call();
  }

  Future<void> _signIn() async {
    final serverClientId = context.read<AppConfig>().serverClientId;
    if (serverClientId == null || serverClientId.isEmpty) {
      setState(() => _status = 'Save the Web Client ID first.');
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final account = await GoogleAuthService.instance.signIn(serverClientId);
      setState(() => _status = 'Signed in as ${account.email}');
      widget.onConfigured?.call();
    } catch (e) {
      setState(() => _status = 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await GoogleAuthService.instance.signOut();
    setState(() => _status = 'Signed out');
    widget.onConfigured?.call();
  }

  Future<void> _saveSheetId() async {
    await context.read<AppConfig>().setSheetId(_sheetIdController.text);
    setState(() => _status = 'Sheet ID saved.');
    widget.onConfigured?.call();
  }

  Future<void> _saveCoingeckoKey() async {
    await context.read<AppConfig>().setCoingeckoApiKey(_coingeckoController.text);
    setState(() => _status = 'CoinGecko API key saved.');
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = GoogleAuthService.instance.isSignedIn;
    final account = GoogleAuthService.instance.account;

    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.firstRun) ...[
          const Text('Welcome', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            "This app uses your Google Sheet as its database. One-time setup: paste the Web Client ID "
            "from Google Cloud Console (see docs/MOBILE_SHEETS_SETUP.md), sign in with the Google account "
            "that already has access to your Watchlist Sheet, then paste the Sheet ID.",
          ),
          const SizedBox(height: 16),
        ],
        const Text('Web Client ID', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'The *Web application* OAuth Client ID (not the Android one) from the same Google Cloud project.',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _serverClientIdController,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '...apps.googleusercontent.com'),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _saveServerClientId, child: const Text('Save Web Client ID')),
        const SizedBox(height: 24),
        const Text('Google account', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (signedIn)
          Row(
            children: [
              Expanded(child: Text(account?.email ?? 'Signed in')),
              TextButton(onPressed: _signOut, child: const Text('Sign out')),
            ],
          )
        else
          FilledButton.icon(
            onPressed: _busy ? null : _signIn,
            icon: const Icon(Icons.login),
            label: const Text('Sign in with Google'),
          ),
        const SizedBox(height: 24),
        const Text('Sheet ID', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          "From the Sheet's URL: docs.google.com/spreadsheets/d/THIS_PART/edit",
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _sheetIdController,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _saveSheetId, child: const Text('Save Sheet ID')),
        const SizedBox(height: 24),
        const Text('CoinGecko API key (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Raises the free public rate limit. Leave blank to use the keyless tier.',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _coingeckoController,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          obscureText: true,
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _saveCoingeckoKey, child: const Text('Save key')),
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
