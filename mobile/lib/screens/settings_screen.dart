import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../google_auth.dart';
import '../widgets/common.dart';
import 'labels_screen.dart';

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
  late final TextEditingController _coinMarketCalController;
  String? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<AppConfig>();
    _serverClientIdController = TextEditingController(text: config.serverClientId ?? '');
    _sheetIdController = TextEditingController(text: config.sheetId ?? '');
    _coingeckoController = TextEditingController(text: config.coingeckoApiKey ?? '');
    _coinMarketCalController = TextEditingController(text: config.coinMarketCalApiKey ?? '');
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

  Future<void> _saveCoinMarketCalKey() async {
    await context.read<AppConfig>().setCoinMarketCalApiKey(_coinMarketCalController.text);
    setState(() => _status = 'CoinMarketCal API key saved.');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final signedIn = GoogleAuthService.instance.isSignedIn;
    final account = GoogleAuthService.instance.account;

    final body = ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomSafePadding(context)),
      children: [
        if (widget.firstRun) ...[
          Text('Welcome', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            "This app uses your Google Sheet as its database. One-time setup: paste the Web Client ID "
            "from Google Cloud Console (see docs/MOBILE_SHEETS_SETUP.md), sign in with the Google account "
            "that already has access to your Watchlist Sheet, then paste the Sheet ID.",
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 20),
        ],
        const SectionHeader(title: 'Web Client ID'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The Web application OAuth Client ID (not the Android one) from the same Google Cloud project.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _serverClientIdController,
                decoration: const InputDecoration(hintText: '...apps.googleusercontent.com'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _saveServerClientId, child: const Text('Save Web Client ID')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Google account'),
        AppCard(
          child: signedIn
              ? Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(Icons.person_rounded, color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(account?.email ?? 'Signed in', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    TextButton(onPressed: _signOut, child: const Text('Sign out')),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _signIn,
                    icon: const Icon(Icons.login_rounded),
                    label: Text(_busy ? 'Signing in…' : 'Sign in with Google'),
                  ),
                ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Sheet ID'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "From the Sheet's URL: docs.google.com/spreadsheets/d/THIS_PART/edit",
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(controller: _sheetIdController),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _saveSheetId, child: const Text('Save Sheet ID')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'CoinGecko API key', subtitle: 'Optional'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Raises the free public rate limit. Leave blank to use the keyless tier.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(controller: _coingeckoController, obscureText: true),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _saveCoingeckoKey, child: const Text('Save key')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'CoinMarketCal API key', subtitle: 'Optional'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Shows a read-only "Upcoming market events" feed on the Dashboard, matched to your '
                'watchlist tickers. Separate from your manually-tracked catalysts and never written to the Sheet. '
                'Free-tier signup at coinmarketcal.com.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(controller: _coinMarketCalController, obscureText: true),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _saveCoinMarketCalKey, child: const Text('Save key')),
              ),
            ],
          ),
        ),
        if (!widget.firstRun) ...[
          const SizedBox(height: 20),
          const SectionHeader(title: 'Watchlist'),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: scheme.secondaryContainer,
                child: Icon(Icons.label_rounded, color: scheme.onSecondaryContainer, size: 18),
              ),
              title: const Text('Manage labels', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('View every label in use, or remove one everywhere'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LabelsScreen())),
            ),
          ),
        ],
        if (_status != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text(_status!, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5))),
            ],
          ),
        ],
      ],
    );

    if (widget.firstRun) {
      return Scaffold(appBar: AppBar(title: const Text('Setup')), body: SafeArea(child: body));
    }
    return Scaffold(appBar: AppBar(title: const Text('Settings')), body: body);
  }
}
