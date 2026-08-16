import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tft_ladder_race/features/auth/presentation/sign_in_screen.dart';

void main() {
  testWidgets('Sign in screen shows the anonymous login button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SignInScreen(
          onAnonymousSignInPressed: _noOpSignIn,
          onEmailSignInPressed: _noOpEmailSignIn,
        ),
      ),
    );

    expect(find.text('Einloggen'), findsOneWidget);
  });
}

Future<void> _noOpSignIn() async {}

Future<void> _noOpEmailSignIn(String email, String password) async {}
