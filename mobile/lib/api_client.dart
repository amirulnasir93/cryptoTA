import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Thin wrapper mirroring packages/frontend/src/api/client.ts -- same
/// endpoints, same contract, just a Dart client instead of a TS/fetch one.
class ApiClient {
  final String baseUrl;
  ApiClient(this.baseUrl);

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query?.isEmpty == true ? null : query);

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final res = await http.get(_uri(path, query), headers: {'Accept': 'application/json'});
    return _handle(res);
  }

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? headers}) async {
    final req = http.Request(method, _uri(path));
    req.headers['Accept'] = 'application/json';
    if (headers != null) req.headers.addAll(headers);
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  dynamic _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.statusCode == 204 || res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String message = 'Request failed: ${res.statusCode}';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] != null) message = body['error'] as String;
    } catch (_) {
      // response wasn't JSON -- keep the generic status message
    }
    throw ApiException(message);
  }

  Future<List<Token>> listTokens({String? status, int? labelId}) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status;
    if (labelId != null) query['labelId'] = labelId.toString();
    final data = await _get('/tokens', query) as List;
    return data.map((t) => Token.fromJson(t as Map<String, dynamic>)).toList();
  }

  Future<TokenDetail> getToken(int id) async => TokenDetail.fromJson(await _get('/tokens/$id') as Map<String, dynamic>);

  Future<Token> createToken(Map<String, dynamic> input) async =>
      Token.fromJson(await _send('POST', '/tokens', body: input) as Map<String, dynamic>);

  Future<Token> updateToken(int id, Map<String, dynamic> input) async =>
      Token.fromJson(await _send('PATCH', '/tokens/$id', body: input) as Map<String, dynamic>);

  Future<void> archiveToken(int id) async => _send('POST', '/tokens/$id/archive');

  Future<void> restoreToken(int id) async => _send('POST', '/tokens/$id/restore');

  Future<void> removeToken(int id) async => _send('DELETE', '/tokens/$id');

  Future<List<Label>> listLabels() async {
    final data = await _get('/labels') as List;
    return data.map((l) => Label.fromJson(l as Map<String, dynamic>)).toList();
  }

  Future<Label> createLabel(String name, String? color) async => Label.fromJson(
        await _send('POST', '/labels', body: {'name': name, if (color != null) 'color': color}) as Map<String, dynamic>,
      );

  Future<void> deleteLabel(int id) async => _send('DELETE', '/labels/$id');

  Future<Catalyst> createCatalyst(Map<String, dynamic> input) async =>
      Catalyst.fromJson(await _send('POST', '/catalysts', body: input) as Map<String, dynamic>);

  Future<void> deleteCatalyst(int id) async => _send('DELETE', '/catalysts/$id');

  Future<DashboardSummary> getDashboard() async =>
      DashboardSummary.fromJson(await _get('/dashboard') as Map<String, dynamic>);

  Future<Map<String, dynamic>> runRefresh(String secret) async =>
      await _send('POST', '/refresh/run', headers: {'x-refresh-secret': secret}) as Map<String, dynamic>;

  Future<Map<String, dynamic>> runSheetSync(String secret) async =>
      await _send('POST', '/sync/sheets/run', headers: {'x-refresh-secret': secret}) as Map<String, dynamic>;

  Future<List<ConflictLogEntry>> listConflicts() async {
    final data = await _get('/sync/conflicts') as List;
    return data.map((c) => ConflictLogEntry.fromJson(c as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> syncCoinMarketCal(String secret) async =>
      await _send('POST', '/catalysts/sync-coinmarketcal', headers: {'x-refresh-secret': secret}) as Map<String, dynamic>;

  Future<TokenAnalysisResult> getTokenAnalysis(int id, String interval) async =>
      TokenAnalysisResult.fromJson(await _get('/tokens/$id/analysis', {'interval': interval}) as Map<String, dynamic>);

  Future<TokenInsightResult> getTokenInsight(int id) async =>
      TokenInsightResult.fromJson(await _get('/tokens/$id/insight') as Map<String, dynamic>);

  Future<List<CoingeckoSearchResult>> searchCoingecko(String query) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/lookup/coingecko', {'q': query}) as List;
    return data.map((c) => CoingeckoSearchResult.fromJson(c as Map<String, dynamic>)).toList();
  }
}
