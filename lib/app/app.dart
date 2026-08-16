import 'package:flutter/material.dart';

import '../features/auth/data/auth_service.dart';
import '../features/auth/presentation/auth_gate.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter App Template',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: AuthGate(authService: AuthService()),
    );
  }
}
