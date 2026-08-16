import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../home/presentation/home_screen.dart';
import '../../home/data/ladder_data_service.dart';
import '../data/auth_service.dart';
import 'sign_in_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return SignInScreen(
            onAnonymousSignInPressed: () async {
              await authService.signInAnonymously();
            },
            onEmailSignInPressed: (email, password) async {
              await authService.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
            },
          );
        }

        return HomeScreen(
          user: user,
          ladderDataService: LadderDataService(),
          onSignOutPressed: () async {
            await authService.signOut();
          },
        );
      },
    );
  }
}
