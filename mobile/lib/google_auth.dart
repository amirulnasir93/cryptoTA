import 'package:google_sign_in/google_sign_in.dart';

const sheetsScopes = ['https://www.googleapis.com/auth/spreadsheets'];

/// Thin wrapper around google_sign_in v7's singleton API (GoogleSignIn.instance
/// with initialize/attemptLightweightAuthentication/authenticate -- not the
/// older per-instance signIn() API from earlier major versions, confirmed
/// against the installed package source before writing this).
class GoogleAuthService {
  static final GoogleAuthService instance = GoogleAuthService._();
  GoogleAuthService._();

  bool _initialized = false;
  GoogleSignInAccount? _account;

  GoogleSignInAccount? get account => _account;
  bool get isSignedIn => _account != null;

  /// [serverClientId] must be a *Web* application OAuth Client ID (not the
  /// Android one) from the same Google Cloud project as the Android client --
  /// required on Android when the app has no google-services.json/Firebase
  /// project (this app has neither). See docs/MOBILE_SHEETS_SETUP.md.
  Future<void> _ensureInitialized(String serverClientId) async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
    _initialized = true;
  }

  /// Restores a previous sign-in silently, if one exists. Call on app start.
  Future<GoogleSignInAccount?> restoreSignIn(String serverClientId) async {
    await _ensureInitialized(serverClientId);
    final future = GoogleSignIn.instance.attemptLightweightAuthentication();
    if (future == null) return null;
    try {
      _account = await future;
    } catch (_) {
      _account = null;
    }
    return _account;
  }

  /// Interactive sign-in, prompting the user. Deliberately does NOT pass
  /// scopeHint here -- that requests a *combined* authentication+authorization
  /// flow, which is what was actually failing with "28444: Developer console
  /// is not set up correctly" (confirmed via adb logcat: plain identity
  /// sign-in succeeded, then the very next step -- authorizing the
  /// spreadsheets scope inline -- failed). The package's own docs recommend
  /// keeping sign-in and scope authorization separate; authHeaders() below
  /// already does the separate authorization call, and is what every real
  /// Sheets request goes through anyway.
  Future<GoogleSignInAccount> signIn(String serverClientId) async {
    await _ensureInitialized(serverClientId);
    _account = await GoogleSignIn.instance.authenticate();
    return _account!;
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    _account = null;
  }

  /// Bearer auth headers for Sheets API calls, prompting for the
  /// spreadsheets scope if it hasn't been granted yet.
  Future<Map<String, String>> authHeaders() async {
    final acc = _account;
    if (acc == null) throw StateError('Not signed in with Google');
    final headers = await acc.authorizationClient.authorizationHeaders(sheetsScopes, promptIfNecessary: true);
    if (headers == null) throw StateError('Could not obtain Google Sheets authorization');
    return headers;
  }
}
