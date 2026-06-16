import 'package:flutter/material.dart';

import 'screens/auth_page.dart';

void main() {
  runApp(const ReadingBuddyApp());
}

class ReadingBuddyApp extends StatelessWidget {
  const ReadingBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Reading Buddy",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFCF7FF),
      ),
      home: const AuthPage(),
    );
  }
}