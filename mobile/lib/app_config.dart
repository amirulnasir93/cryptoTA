import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the two pieces of local config the app needs before it can talk to
/// the backend at all: where it is (no single right answer -- an Android
/// emulator reaches the host machine at 10.0.2.2, a physical phone needs the
/// host's LAN IP, and a deployed backend would use its real URL) and the
/// refresh secret (mirrors the web app's Settings page / useRefreshSecret
/// hook -- the same shared-secret header protecting /refresh/run etc.).
class AppConfig extends ChangeNotifier {
  static const _baseUrlKey = 'base_url';
  static const _refreshSecretKey = 'refresh_secret';

  String? _baseUrl;
  String? _refreshSecret;
  bool _loaded = false;

  String? get baseUrl => _baseUrl;
  String? get refreshSecret => _refreshSecret;
  bool get isConfigured => _baseUrl != null && _baseUrl!.isNotEmpty;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey);
    _refreshSecret = prefs.getString(_refreshSecretKey);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, trimmed);
    _baseUrl = trimmed;
    notifyListeners();
  }

  Future<void> setRefreshSecret(String secret) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshSecretKey, secret);
    _refreshSecret = secret;
    notifyListeners();
  }
}
