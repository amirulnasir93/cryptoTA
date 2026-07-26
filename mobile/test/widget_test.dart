import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_watchlist_mobile/app_config.dart';
import 'package:crypto_watchlist_mobile/main.dart';

void main() {
  testWidgets('shows first-run setup when no backend URL is configured', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppConfig()..load(),
        child: const CryptoWatchlistApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
  });
}
