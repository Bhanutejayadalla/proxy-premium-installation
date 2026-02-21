import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dual_mode_app/app_state.dart';
import 'package:dual_mode_app/screens/auth_screen.dart';
import 'package:dual_mode_app/constants.dart';

void main() {
  testWidgets('Auth Screen renders login form', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => AppState())],
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    // Verify basic auth UI elements
    expect(find.text('Proxi'), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
  });

  test('AppState initialises in formal mode', () {
    final state = AppState();
    expect(state.isFormal, true);
    expect(state.currentUser, isNull);
  });

  test('AppColors provides formal and casual colours', () {
    expect(AppColors.formalBg, isNotNull);
    expect(AppColors.casualStart, isNotNull);
    expect(AppColors.casualEnd, isNotNull);
    expect(AppColors.formalAccent, isNotNull);
    expect(AppColors.casualAccent, isNotNull);
  });
}