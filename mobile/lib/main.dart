import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_config.dart';
import 'api_client.dart';
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

/// Provides the ApiClient (rebuilt whenever the base URL changes) to the rest
/// of the tree, and gates the main app behind first-run setup -- there's no
/// sensible default base URL (emulator vs. physical device vs. a deployed
/// backend all differ), so the app asks for it once rather than guessing.
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfig>();
    if (!config.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!config.isConfigured) {
      return const SettingsScreen(firstRun: true);
    }
    return Provider<ApiClient>(
      key: ValueKey(config.baseUrl),
      create: (_) => ApiClient(config.baseUrl!),
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
