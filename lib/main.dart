import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:joi_mobile/firebase_options.dart';
import 'package:joi_mobile/screens/login_screen.dart';
import 'package:joi_mobile/services/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Database
  await DatabaseHelper.instance.database;

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
