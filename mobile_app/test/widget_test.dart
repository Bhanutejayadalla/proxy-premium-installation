// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:dual_mode_app/app_state.dart';
import 'package:dual_mode_app/screens/auth_screen.dart';
import 'package:dual_mode_app/constants.dart';

class MockAppState extends Mock with ChangeNotifier implements AppState {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
  });

  testWidgets('Auth Screen renders login form', (WidgetTester tester) async {
    final appState = MockAppState();
    when(() => appState.isFormal).thenReturn(true);
    when(() => appState.currentUser).thenReturn(null);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<AppState>.value(value: appState)],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    // Verify basic auth UI elements
    expect(find.text('Proxi Premium'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('Auth Screen builds with mocked AppState (no Firebase backend)',
      (WidgetTester tester) async {
    final appState = MockAppState();
    when(() => appState.isFormal).thenReturn(true);
    when(() => appState.currentUser).thenReturn(null);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    expect(find.byType(AuthScreen), findsOneWidget);
  });

  test('AppColors provides formal and casual colours', () {
    expect(AppColors.formalBg, isNotNull);
    expect(AppColors.casualStart, isNotNull);
    expect(AppColors.casualEnd, isNotNull);
    expect(AppColors.formalAccent, isNotNull);
    expect(AppColors.casualAccent, isNotNull);
  });
}