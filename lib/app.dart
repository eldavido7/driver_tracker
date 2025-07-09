import 'package:flutter/material.dart';
import 'features/auth/auth_gate.dart';
import 'features/session/welcome.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driver Tracker',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const AuthGate(), // ✅ First screen
      routes: {
        '/home': (context) => const WelcomePage(),
        // ✅ No need for '/' here — AuthGate decides between LoginPage and WelcomePage
      },
    );
  }
}
