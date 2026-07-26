import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the local config the app needs before it can do anything: the
/// Google Sheet ID it treats as its database (same Sheet/layout the web
/// app's Settings page and docs/SHEETS_SETUP.md already document -- there's
/// no separate backend to point at anymore) and an optional CoinGecko API
/// key, which raises the free public tier's rate limit the same way
/// COINGECKO_API_KEY does for the web backend's .env.
///
/// Google sign-in itself is *not* tracked here -- google_sign_in persists
/// its own session (see google_auth.dart's restoreSignIn), so this only
/// needs to remember which Sheet to use once signed in.
class AppConfig extends ChangeNotifier {
  static const _sheetIdKey = 'sheet_id';
  static const _coingeckoApiKeyKey = 'coingecko_api_key';
  static const _coinMarketCalApiKeyKey = 'coinmarketcal_api_key';
  static const _serverClientIdKey = 'server_client_id';

  String? _sheetId;
  String? _coingeckoApiKey;
  String? _coinMarketCalApiKey;
  String? _serverClientId;
  bool _loaded = false;

  String? get sheetId => _sheetId;
  String? get coingeckoApiKey => _coingeckoApiKey;
  // Free-tier signup at coinmarketcal.com/en/api -- shows a read-only
  // "Upcoming market events" feed on the Dashboard, separate from
  // manually-tracked catalysts. Optional, same as the CoinGecko key.
  String? get coinMarketCalApiKey => _coinMarketCalApiKey;
  // The *Web* OAuth Client ID (not the Android one) -- required as
  // GoogleSignIn.initialize's serverClientId on Android when the app has no
  // google-services.json/Firebase project, per the google_sign_in_android
  // package's own integration docs. See google_auth.dart.
  String? get serverClientId => _serverClientId;
  bool get isConfigured =>
      _sheetId != null && _sheetId!.isNotEmpty && _serverClientId != null && _serverClientId!.isNotEmpty;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _sheetId = prefs.getString(_sheetIdKey);
    _coingeckoApiKey = prefs.getString(_coingeckoApiKeyKey);
    _coinMarketCalApiKey = prefs.getString(_coinMarketCalApiKeyKey);
    _serverClientId = prefs.getString(_serverClientIdKey);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setSheetId(String id) async {
    final trimmed = id.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sheetIdKey, trimmed);
    _sheetId = trimmed;
    notifyListeners();
  }

  Future<void> setServerClientId(String id) async {
    final trimmed = id.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverClientIdKey, trimmed);
    _serverClientId = trimmed;
    notifyListeners();
  }

  Future<void> setCoingeckoApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_coingeckoApiKeyKey, key);
    _coingeckoApiKey = key;
    notifyListeners();
  }

  Future<void> setCoinMarketCalApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_coinMarketCalApiKeyKey, key);
    _coinMarketCalApiKey = key;
    notifyListeners();
  }
}
