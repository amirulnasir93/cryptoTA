import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_config.dart';
import 'google_auth.dart';
import 'sheets_client.dart';
import 'repository.dart';
import 'screens/dashboard_screen.dart';
import 'screens/watchlist_screen.dart';
import 'screens/labels_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppConfig()..load(),
      child: const CryptoWatchlistApp(),
    ),
  );
}

class CryptoWatchlistApp extends StatelessWidget {
  const CryptoWatchlistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crypto Watchlist',
      theme: ThemeData(colorSchemeSeed: Colors.blue, brightness: Brightness.light, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: Colors.blue, brightness: Brightness.dark, useMaterial3: true),
      home: const AppRoot(),
    );
  }
}

/// Gates the main app behind first-run setup: signing in with Google (the
/// Sheet is the app's only database now, see the approved plan) and pointing
/// at a Sheet ID. Neither has a sane default to guess, so the app asks once
/// rather than assuming.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _checkingSignIn = true;
  bool _signedIn = false;
  bool _restoreAttempted = false;

  // GoogleSignIn.initialize needs the Web Client ID from AppConfig, which
  // isn't available until AppConfig finishes loading -- so the restore
  // attempt can't happen in initState like a simpler check could; it's
  // triggered once from build() as soon as both are ready.
  Future<void> _restoreSignIn(String serverClientId) async {
    _restoreAttempted = true;
    final account = await GoogleAuthService.instance.restoreSignIn(serverClientId);
    if (mounted) {
      setState(() {
        _signedIn = account != null;
        _checkingSignIn = false;
      });
    }
  }

  void _onConfigured() {
    setState(() => _signedIn = GoogleAuthService.instance.isSignedIn);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfig>();
    if (!config.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // No Web Client ID yet: there's nothing to silently restore, and first
    // run needs it anyway -- skip straight to setup instead of waiting.
    if (config.serverClientId == null || config.serverClientId!.isEmpty) {
      return SettingsScreen(firstRun: true, onConfigured: _onConfigured);
    }

    if (!_restoreAttempted) {
      _restoreSignIn(config.serverClientId!);
    }
    if (_checkingSignIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_signedIn || !config.isConfigured) {
      return SettingsScreen(firstRun: true, onConfigured: _onConfigured);
    }
    return Provider<AppRepository>(
      key: ValueKey(config.sheetId),
      create: (_) => AppRepository(SheetsClient(config.sheetId!), coingeckoApiKey: config.coingeckoApiKey),
      child: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    WatchlistScreen(),
    LabelsScreen(),
    SettingsScreen(firstRun: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Watchlist'),
          NavigationDestination(icon: Icon(Icons.label_outline), selectedIcon: Icon(Icons.label), label: 'Labels'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
