import 'package:flutter/material.dart';
import 'package:joi_mobile/screens/login_screen.dart';
import 'package:joi_mobile/services/database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database; // Initialize DB
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JOI Chatbot',
      theme: ThemeData(
        primaryColor: const Color(0xFF4EE0FF),
        scaffoldBackgroundColor: Colors.transparent,
        fontFamily: 'SpaceMono',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFDCD6E0)),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
