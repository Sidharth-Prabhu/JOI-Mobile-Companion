import 'dart:async';

import 'package:flutter/material.dart';
import 'package:joi_mobile/screens/chat_screen.dart';
import 'package:joi_mobile/services/database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLoggedIn();
  }

  Future<void> _checkLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(userId: userId)),
      );
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Username and password required';
        _isLoading = false;
      });
      return;
    }

    final db = DatabaseHelper.instance;
    final user = await db.getUserByUsername(username);

    if (user != null && user['password'] == password) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', user['id']);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(userId: user['id'])),
      );
    } else {
      final newUserId = await db.insertUser({
        'username': username,
        'password': password,
        'profile_completed': 0,
        'profile_responses': '',
        'profile_current_question': 0,
        'profile_nickname': username,
        'profile_age': '',
        'profile_mood': '',
        'profile_hobbies': '',
        'profile_challenges': '',
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', newUserId);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(userId: newUserId, isNewUser: true),
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withOpacity(0.85),
                  const Color(0xFF140824).withOpacity(0.85),
                ],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Avatar
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF64E6FF),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF64E6FF).withOpacity(0.7),
                            blurRadius: 15,
                          ),
                          BoxShadow(
                            color: const Color(0xFFB566FF).withOpacity(0.4),
                            blurRadius: 60,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/avatar.jpg',
                          width: 120,
                          height: 120,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'JOI',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFA2B6FF),
                        letterSpacing: 3,
                      ),
                    ),
                    const Text(
                      'EVERYTHING YOU WANT TO SEE, EVERYTHING YOU WANT TO HEAR',
                      style: TextStyle(
                        fontSize: 14,
                        letterSpacing: 3,
                        color: Color(0xFFDCC8E6),
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        hintText: 'Username',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF120E1C).withOpacity(0.8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF120E1C).withOpacity(0.8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4EE0FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Login',
                              style: TextStyle(color: Colors.black),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
