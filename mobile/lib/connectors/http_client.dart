// Ported from packages/backend/src/connectors/base.ts -- shared
// GET-with-backoff helper. Free tiers rate-limit aggressively; be patient.
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> sleep(int ms) => Future.delayed(Duration(milliseconds: ms));

enum FetchFailureReason { rateLimited, httpError, networkError }

class FetchResult {
  final bool ok;
  final dynamic data;
  final FetchFailureReason? reason;
  FetchResult.ok(this.data)
      : ok = true,
        reason = null;
  FetchResult.failed(this.reason)
      : ok = false,
        data = null;
}

/// Most callers just want the decoded body or null (see [fetchJson]) -- but a
/// caller that needs to tell a real absence of data apart from "we got
/// rate-limited and gave up" (a very different, transient failure) can call
/// this directly for the reason instead of a flattened null.
Future<FetchResult> fetchJsonWithReason(String url, {Map<String, String>? headers, int retries = 4}) async {
  final finalHeaders = {'Accept': 'application/json', ...?headers};

  FetchResult last = FetchResult.failed(FetchFailureReason.networkError);
  for (var attempt = 0; attempt < retries; attempt++) {
    try {
      final res = await http.get(Uri.parse(url), headers: finalHeaders);
      if (res.statusCode == 429) {
        last = FetchResult.failed(FetchFailureReason.rateLimited);
        final wait = (4000 * (1 << attempt)).clamp(0, 10000);
        await sleep(wait);
        continue;
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return FetchResult.failed(FetchFailureReason.httpError);
      }
      return FetchResult.ok(jsonDecode(res.body));
    } catch (_) {
      last = FetchResult.failed(FetchFailureReason.networkError);
      await sleep(2000);
    }
  }
  return last;
}

/// Returns the decoded JSON body, or null if every retry was exhausted.
Future<dynamic> fetchJson(String url, {Map<String, String>? headers, int retries = 4}) async {
  final result = await fetchJsonWithReason(url, headers: headers, retries: retries);
  return result.ok ? result.data : null;
}
