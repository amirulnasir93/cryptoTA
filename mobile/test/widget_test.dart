import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_watchlist_mobile/app_config.dart';
import 'package:crypto_watchlist_mobile/screens/settings_screen.dart';

void main() {
  testWidgets('first-run Settings screen prompts for Google sign-in and a Sheet ID', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final config = AppConfig();
    await config.load();

    // The redesigned Settings screen's card-based sections take noticeably
    // more vertical space than the old compact layout -- a tall test surface
    // keeps every section built (Flutter's ListView only builds children
    // near the viewport) without needing to simulate scrolling.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // SettingsScreen itself never touches Google Sign-In's platform channels
    // unless a button is tapped -- isSignedIn/account are plain local getters
    // -- so this renders safely without a real device or platform mocking,
    // unlike routing through AppRoot's sign-in restoration.
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: config,
        child: const MaterialApp(home: SettingsScreen(firstRun: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Sheet ID'), findsOneWidget);
  });
}
