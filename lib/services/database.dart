import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._privateConstructor();

  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._privateConstructor();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'emotional_support.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password TEXT,
        profile_completed INTEGER,
        profile_responses TEXT,
        profile_current_question INTEGER,
        profile_nickname TEXT,
        profile_age TEXT,
        profile_mood TEXT,
        profile_hobbies TEXT,
        profile_challenges TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        message TEXT,
        response TEXT,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', user);
  }

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>> getUser(int id) async {
    final db = await database;
    final results = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return results.first;
  }

  Future<void> updateUser(int id, Map<String, dynamic> updates) async {
    final db = await database;
    await db.update('users', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateUserProfile(int id, String key, String value) async {
    await updateUser(id, {'profile_$key': value});
  }

  Future<void> addProfileResponse(int id, String response) async {
    final user = await getUser(id);
    List<String> responses = (user['profile_responses'] as String).isEmpty
        ? []
        : (user['profile_responses'] as String).split(',');
    responses.add(response);
    await updateUser(id, {'profile_responses': responses.join(',')});
  }

  Future<int> insertConversation(
    int userId,
    String message,
    String response,
  ) async {
    final db = await database;
    return await db.insert('conversations', {
      'user_id': userId,
      'message': message,
      'response': response,
    });
  }

  Future<List<Map<String, dynamic>>> getRecentConversations(
    int userId, {
    int limit = 5,
  }) async {
    final db = await database;
    return await db.query(
      'conversations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
      limit: limit,
    );
  }
}
