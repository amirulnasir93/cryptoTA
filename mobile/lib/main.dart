import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'app_config.dart';
import 'google_auth.dart';
import 'sheets_client.dart';
import 'repository.dart';
import 'theme.dart';
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
    return const AppRoot();
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
  // The one-time "is there already a signed-in session?" check only ever
  // happens once per app launch -- once _initialCheckComplete flips true, it
  // never resets. Without that guard, EVERY AppConfig change (saving the
  // Sheet ID, the CoinGecko key, even re-saving the same Web Client ID) would
  // re-run this check and briefly swap SettingsScreen out for a loading
  // spinner and back, tearing down and recreating its State -- which is
  // exactly what made "Save Web Client ID" look like it did nothing: the
  // value *was* saved, but the "saved" confirmation text lived on the old,
  // now-destroyed SettingsScreen instance.
  bool _initialCheckComplete = false;
  bool _restoreAttempted = false;
  bool _signedIn = false;

  Future<void> _restoreSignIn(String serverClientId) async {
    GoogleSignInAccount? account;
    try {
      account = await GoogleAuthService.instance.restoreSignIn(serverClientId);
    } catch (_) {
      account = null;
    }
    if (mounted) {
      setState(() {
        _signedIn = account != null;
        _initialCheckComplete = true;
      });
    }
  }

  void _onConfigured() {
    setState(() {
      _signedIn = GoogleAuthService.instance.isSignedIn;
      _initialCheckComplete = true;
    });
  }

  static final _theme = buildLightTheme();
  static final _darkTheme = buildDarkTheme();

  MaterialApp _shell({required Widget home}) {
    return MaterialApp(
      title: 'Crypto Watchlist',
      debugShowCheckedModeBanner: false,
      theme: _theme,
      darkTheme: _darkTheme,
      home: home,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfig>();
    if (!config.loaded) {
      return _shell(home: const Scaffold(body: Center(child: CircularProgressIndicator())));
    }

    if (!_initialCheckComplete) {
      // _restoreAttempted only guards *triggering* the check once; the
      // spinner itself stays up on every rebuild until _initialCheckComplete
      // flips, so an unrelated rebuild arriving mid-check can't fall through
      // to Setup early.
      if (!_restoreAttempted) {
        _restoreAttempted = true;
        final serverClientId = config.serverClientId;
        if (serverClientId == null || serverClientId.isEmpty) {
          // Nothing to silently restore -- mark the check done after this
          // frame (not synchronously mid-build) and fall through to Setup.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _initialCheckComplete = true);
          });
        } else {
          _restoreSignIn(serverClientId);
        }
      }
      return _shell(home: const Scaffold(body: Center(child: CircularProgressIndicator())));
    }

    if (!_signedIn || !config.isConfigured) {
      return _shell(home: SettingsScreen(firstRun: true, onConfigured: _onConfigured));
    }
    // Provider<AppRepository> wraps MaterialApp itself here (not just
    // AppShell) so its Navigator's PUSHED routes -- e.g. TokenDetailScreen,
    // reached via Navigator.push, not a child of whatever screen triggered
    // it -- still have this Provider as an ancestor. A push adds its route
    // as a new sibling entry in the Navigator's own Overlay, not as a
    // descendant of the pushing widget, so a Provider that only wraps
    // AppShell (the first/root route's content) is invisible to every route
    // pushed afterward -- confirmed live: this exact structure produced
    // "Could not find the correct Provider<AppRepository>" when opening a
    // token's detail screen.
    return Provider<AppRepository>(
      key: ValueKey(config.sheetId),
      create: (_) => AppRepository(SheetsClient(config.sheetId!), coingeckoApiKey: config.coingeckoApiKey),
      child: _shell(home: const AppShell()),
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
