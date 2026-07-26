// Raw Sheets API v4 REST calls (no `googleapis` package -- consistent with
// how the rest of this app talks to everything else, plain `http` calls).
// Column layout matches packages/backend/src/sheets/sheetsClient.ts's
// SHEET_HEADERS exactly, so the phone and the web app's sync job can read/
// write the same "Watchlist" tab without stepping on each other.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'google_auth.dart';

const _sheetsApi = 'https://sheets.googleapis.com/v4/spreadsheets';

class SheetTab {
  final String title;
  final List<String> headers;
  const SheetTab(this.title, this.headers);
}

const watchlistTab = SheetTab('Watchlist', [
  'Ticker',
  'Project',
  'Chain',
  'Contract',
  'CoinGecko ID',
  'DefiLlama Slug',
  'Binance Symbol',
  'MEXC Symbol',
  'Cluster',
  'Notes',
  'Labels',
  'Status',
]);

const catalystsTab = SheetTab('Catalysts', [
  'Ticker',
  'Date',
  'Type',
  'Description',
  'SizePct',
  'SourceUrl',
]);

String _columnLetter(int zeroBasedIndex) => String.fromCharCode(0x41 + zeroBasedIndex); // 'A' + n, single-letter only

class SheetsApiException implements Exception {
  final String message;
  SheetsApiException(this.message);
  @override
  String toString() => 'SheetsApiException: $message';
}

class SheetsClient {
  final String spreadsheetId;
  SheetsClient(this.spreadsheetId);

  Future<Map<String, String>> _headers() async {
    final h = await GoogleAuthService.instance.authHeaders();
    return {...h, 'Content-Type': 'application/json'};
  }

  void _check(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SheetsApiException('Sheets API ${res.statusCode}: ${res.body}');
    }
  }

  /// Maps existing tab titles to their sheetId (gid) -- needed for row
  /// deletion, which operates on gid + a 0-based row index, not a title.
  Future<Map<String, int>> _tabIds() async {
    final headers = await _headers();
    final uri = Uri.parse('$_sheetsApi/$spreadsheetId').replace(queryParameters: {
      'fields': 'sheets.properties',
    });
    final res = await http.get(uri, headers: headers);
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final sheets = (body['sheets'] as List?) ?? [];
    return {
      for (final s in sheets)
        (s['properties']['title'] as String): (s['properties']['sheetId'] as int),
    };
  }

  /// Creates the tab with its header row if it doesn't exist yet -- mirrors
  /// getWatchlistSheet()'s auto-create behavior in the web backend.
  Future<int> ensureTab(SheetTab tab) async {
    final tabIds = await _tabIds();
    if (tabIds.containsKey(tab.title)) return tabIds[tab.title]!;

    final headers = await _headers();
    final addRes = await http.post(
      Uri.parse('$_sheetsApi/$spreadsheetId:batchUpdate'),
      headers: headers,
      body: jsonEncode({
        'requests': [
          {
            'addSheet': {
              'properties': {'title': tab.title},
            },
          },
        ],
      }),
    );
    _check(addRes);
    final addBody = jsonDecode(addRes.body) as Map<String, dynamic>;
    final sheetId = addBody['replies'][0]['addSheet']['properties']['sheetId'] as int;

    final lastCol = _columnLetter(tab.headers.length - 1);
    await _rawUpdate('${tab.title}!A1:${lastCol}1', [tab.headers]);
    return sheetId;
  }

  Future<void> _rawUpdate(String range, List<List<String>> values) async {
    final headers = await _headers();
    final res = await http.put(
      Uri.parse('$_sheetsApi/$spreadsheetId/values/${Uri.encodeComponent(range)}')
          .replace(queryParameters: {'valueInputOption': 'USER_ENTERED'}),
      headers: headers,
      body: jsonEncode({'values': values}),
    );
    _check(res);
  }

  /// Reads every data row (header excluded) for a tab. Short rows (trailing
  /// empty cells Sheets doesn't bother returning) are padded to the full
  /// column count so callers can always index by column position.
  Future<List<List<String>>> readRows(SheetTab tab) async {
    await ensureTab(tab);
    final headers = await _headers();
    final lastCol = _columnLetter(tab.headers.length - 1);
    final range = '${tab.title}!A2:$lastCol';
    final res = await http.get(
      Uri.parse('$_sheetsApi/$spreadsheetId/values/${Uri.encodeComponent(range)}'),
      headers: headers,
    );
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = (body['values'] as List?) ?? [];
    return rows.map((row) {
      final cells = (row as List).map((c) => '$c').toList();
      while (cells.length < tab.headers.length) {
        cells.add('');
      }
      return cells;
    }).toList();
  }

  /// Appends one row. Returns the 1-based sheet row number it landed on.
  Future<int> appendRow(SheetTab tab, List<String> values) async {
    await ensureTab(tab);
    final headers = await _headers();
    final lastCol = _columnLetter(tab.headers.length - 1);
    final range = '${tab.title}!A1:$lastCol';
    final res = await http.post(
      Uri.parse('$_sheetsApi/$spreadsheetId/values/${Uri.encodeComponent(range)}:append').replace(
        queryParameters: {'valueInputOption': 'USER_ENTERED', 'insertDataOption': 'INSERT_ROWS'},
      ),
      headers: headers,
      body: jsonEncode({'values': [values]}),
    );
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final updatedRange = body['updates']['updatedRange'] as String; // e.g. "Watchlist!A5:L5"
    final match = RegExp(r'![A-Z]+(\d+)').firstMatch(updatedRange);
    return int.parse(match!.group(1)!);
  }

  /// Overwrites row [rowNumber] (1-based, header is row 1) with [values].
  Future<void> updateRow(SheetTab tab, int rowNumber, List<String> values) async {
    final lastCol = _columnLetter(tab.headers.length - 1);
    await _rawUpdate('${tab.title}!A$rowNumber:$lastCol$rowNumber', [values]);
  }

  /// Deletes row [rowNumber] (1-based, header is row 1) entirely, shifting
  /// rows below it up -- used for removing a catalyst.
  Future<void> deleteRow(SheetTab tab, int rowNumber) async {
    final tabIds = await _tabIds();
    final sheetId = tabIds[tab.title];
    if (sheetId == null) return;
    final headers = await _headers();
    final res = await http.post(
      Uri.parse('$_sheetsApi/$spreadsheetId:batchUpdate'),
      headers: headers,
      body: jsonEncode({
        'requests': [
          {
            'deleteDimension': {
              'range': {
                'sheetId': sheetId,
                'dimension': 'ROWS',
                'startIndex': rowNumber - 1,
                'endIndex': rowNumber,
              },
            },
          },
        ],
      }),
    );
    _check(res);
  }
}
