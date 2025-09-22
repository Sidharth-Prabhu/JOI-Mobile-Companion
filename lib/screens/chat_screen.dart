import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:joi_mobile/services/database.dart';
import 'package:joi_mobile/services/gemini_service.dart';
import 'package:joi_mobile/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatScreen extends StatefulWidget {
  final int userId;
  final bool isNewUser;

  const ChatScreen({super.key, required this.userId, this.isNewUser = false});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  bool _isVoiceMode = false;
  bool _isListening = false;
  Map<String, dynamic> _user = {};
  final List<String> _questionnaire = [
    "What's your age?",
    "How would you describe your current mood?",
    "What are some things you enjoy doing?",
    "What challenges are you facing right now?",
  ];
  final GeminiService _geminiService = GeminiService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  late AnimationController _voiceAnimationController;
  late Animation<double> _voiceAnimation;

  @override
  void initState() {
    super.initState();
    _geminiService.init();
    _voiceAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _voiceAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _voiceAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _loadUserAndConversations();
    _initializeNewChat();
  }

  @override
  void dispose() {
    _geminiService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _voiceAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndConversations() async {
    final db = DatabaseHelper.instance;
    try {
      _user = await db.getUser(widget.userId) ?? {};
    } catch (e) {
      print('Error loading user: $e');
      _user = {};
    }
    setState(() {});
    _scrollToBottom();
  }

  void _initializeNewChat() {
    if (widget.isNewUser ||
        (_user.isNotEmpty && _user['profile_completed'] == 0)) {
      _addMessage(
        'JOI - EVERYTHING YOU WANT TO SEE, EVERYTHING YOU WANT TO HEAR\nWelcome! Let\'s get to know you better. ${_questionnaire[0]}',
        isUser: false,
      );
    } else if (_user.isNotEmpty) {
      _addMessage(
        'JOI - EVERYTHING YOU WANT TO SEE, EVERYTHING YOU WANT TO HEAR\nWelcome back! I remember your mood is ${_user['profile_mood'] ?? 'unknown'} and you enjoy ${_user['profile_hobbies'] ?? 'various activities'}. How can I assist you today?',
        isUser: false,
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addMessage(String text, {bool isUser = true}) {
    setState(() {
      _messages.add(isUser ? {'message': text} : {'response': text});
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage({bool isVoice = false}) async {
    String message = '';

    if (isVoice && !_isListening) {
      // Start voice recognition
      setState(() => _isListening = true);
      _voiceAnimationController.repeat(reverse: true);

      bool available = await _speech.initialize(
        onStatus: (status) => print('Speech status: $status'),
        onError: (error) => print('Speech error: $error'),
      );

      if (available) {
        await _speech.listen(
          onResult: (result) {
            setState(() {
              message = result.recognizedWords;
              if (result.finalResult) {
                _messageController.text = message;
              }
            });
          },
          localeId: 'en_US',
        );

        // Stop after 5 seconds or when final result
        Timer(const Duration(seconds: 5), () async {
          await _speech.stop();
          setState(() => _isListening = false);
          _voiceAnimationController.stop();
          _voiceAnimationController.reset();

          if (message.isNotEmpty) {
            _sendMessage(isVoice: false); // Process as text
          }
        });
      } else {
        setState(() => _isListening = false);
        _addMessage('Voice recognition not available', isUser: false);
      }
      return;
    }

    if (!isVoice) {
      message = _messageController.text.trim();
      if (message.isEmpty) return;
      _addMessage(message);
      _messageController.clear();
    }

    setState(() => _isTyping = true);

    final db = DatabaseHelper.instance;
    final updateKey = _parseProfileUpdate(message);
    if (updateKey != null) {
      await db.updateUserProfile(
        widget.userId,
        updateKey['key']!,
        updateKey['value']!,
      );
      final response =
          'Updated your ${updateKey['key']} to ${updateKey['value']}. JOI - EVERYTHING YOU WANT TO SEE, EVERYTHING YOU WANT TO HEAR\nHow can I assist you now?';
      _addMessage(response, isUser: false);
      if (isVoice)
        await _geminiService.speakText(response); // Speak in voice mode
      await db.insertConversation(widget.userId, message, response);
      setState(() => _isTyping = false);
      _loadUserAndConversations();
      return;
    }

    if (_user.isNotEmpty && _user['profile_completed'] == 0) {
      final currentQuestion = _user['profile_current_question'] as int? ?? 0;
      if (currentQuestion < _questionnaire.length) {
        final fields = ['age', 'mood', 'hobbies', 'challenges'];
        await db.updateUserProfile(
          widget.userId,
          fields[currentQuestion],
          message,
        );
        await db.addProfileResponse(widget.userId, message);

        String response;
        if (currentQuestion + 1 < _questionnaire.length) {
          await db.updateUser(widget.userId, {
            'profile_current_question': currentQuestion + 1,
          });
          response = _questionnaire[currentQuestion + 1];
        } else {
          await db.updateUser(widget.userId, {'profile_completed': 1});
          response =
              "Thank you for completing the questionnaire! JOI - EVERYTHING YOU WANT TO SEE, EVERYTHING YOU WANT TO HEAR\nHow can I assist you now?";
        }
        _addMessage(response, isUser: false);
        if (isVoice)
          await _geminiService.speakText(response); // Speak in voice mode
        await db.insertConversation(widget.userId, message, response);
        setState(() => _isTyping = false);
        _loadUserAndConversations();
        return;
      }
    }

    // Generate response with Gemini
    final history = await db.getRecentConversations(widget.userId, limit: 10);
    final historyText = history
        .map((c) => 'User: ${c['message']}\nJOI: ${c['response']}')
        .join('\n');
    final profile = {
      'nickname': _user['profile_nickname'] ?? 'unknown',
      'age': _user['profile_age'] ?? 'unknown',
      'mood': _user['profile_mood'] ?? 'unknown',
      'hobbies': _user['profile_hobbies'] ?? 'unknown',
      'challenges': _user['profile_challenges'] ?? 'unknown',
    };

    final prompt =
        """
${GeminiService.joiSystemPrompt}
User profile: nickname=${profile['nickname']}, age=${profile['age']}, mood=${profile['mood']}, hobbies=${profile['hobbies']}, challenges=${profile['challenges']}
Recent conversation history:
$historyText
User message: $message
Respond with empathy and tailor your response to the user's emotional state, interests, and past interactions where possible.
""";

    String accumulatedText = '';
    await for (final chunk in _geminiService.generateContentStream(prompt)) {
      setState(() {
        accumulatedText += chunk;
        if (_messages.last.containsKey('response')) {
          _messages.last['response'] = accumulatedText;
        } else {
          _messages.add({'response': accumulatedText});
        }
      });
      _scrollToBottom();
    }

    if (isVoice)
      await _geminiService.speakText(accumulatedText); // Speak in voice mode
    await db.insertConversation(widget.userId, message, accumulatedText);
    setState(() => _isTyping = false);
  }

  Map<String, String>? _parseProfileUpdate(String message) {
    final patterns = {
      'nickname': RegExp(r'update my nickname to (.+)', caseSensitive: false),
      'age': RegExp(r'update my age to (\d+)', caseSensitive: false),
      'mood': RegExp(r'my mood is (.+)', caseSensitive: false),
      'hobbies': RegExp(r'my hobbies are (.+)', caseSensitive: false),
      'challenges': RegExp(r'my challenges are (.+)', caseSensitive: false),
    };
    for (final entry in patterns.entries) {
      final match = entry.value.firstMatch(message);
      if (match != null) {
        return {'key': entry.key, 'value': match.group(1)!};
      }
    }
    return null;
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'JOI',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: Color(0xFFA2B6FF),
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
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
      ),
      body: Stack(
        children: [
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
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: const Text(
                  'EVERYTHING YOU WANT TO SEE, EVERYTHING YOU WANT TO HEAR',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 2,
                    color: Color(0xFFDCC8E6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  padding: const EdgeInsets.all(8.0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isTyping) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 8,
                                height: 8,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF4EE0FF),
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: 8,
                                height: 8,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF4EE0FF),
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: 8,
                                height: 8,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF4EE0FF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final msg = _messages[index];
                    final isUser = msg.containsKey('message');
                    final text = isUser ? msg['message']! : msg['response']!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4.0,
                        horizontal: 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: isUser
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser) ...[
                            Container(
                              margin: const EdgeInsets.only(right: 8.0),
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.transparent,
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/avatar.jpg',
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                          Flexible(
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              margin: const EdgeInsets.only(
                                top: 4.0,
                                bottom: 4.0,
                              ),
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                gradient: isUser
                                    ? LinearGradient(
                                        colors: [
                                          const Color(0xFF482C5F),
                                          const Color(0xFF271B3F),
                                        ],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          const Color(0xFF0E102E),
                                          const Color(0xFF140F23),
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: isUser
                                  ? Text(
                                      text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    )
                                  : MarkdownBody(
                                      data: text,
                                      styleSheet: MarkdownStyleSheet(
                                        p: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                        ),
                                        strong: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        em: const TextStyle(
                                          color: Colors.white,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        listBullet: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        blockquote: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        code: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'SpaceMono',
                                          backgroundColor: Colors.black26,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          if (isUser) ...[
                            Container(
                              margin: const EdgeInsets.only(left: 8.0),
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(
                                  0xFF4EE0FF,
                                ).withOpacity(0.3),
                                child: const Icon(
                                  Icons.person,
                                  color: Color(0xFF4EE0FF),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Voice visualization when listening
              if (_isListening)
                Container(
                  height: 60,
                  padding: const EdgeInsets.all(8.0),
                  child: WaveWidget(
                    config: CustomConfig(
                      gradients: [
                        [const Color(0xFF4EE0FF), const Color(0xFFB565FF)],
                      ],
                      durations: [
                        3500,
                      ], // Duration in milliseconds for wave animation
                      heightPercentages: [
                        0.25,
                        0.30,
                      ], // Percentage of height for each wave layer
                      gradientBegin: Alignment.bottomLeft,
                      gradientEnd: Alignment.topRight,
                    ),
                    size: Size(MediaQuery.of(context).size.width, 60),
                    waveAmplitude: 10.0,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              // Input row
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: Row(
                  children: [
                    if (!_isVoiceMode) ...[
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          enabled: !_isListening,
                          decoration: InputDecoration(
                            hintText: _isListening
                                ? 'Listening...'
                                : 'Type your message...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF120E1C).withOpacity(0.8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          maxLines: null,
                          minLines: 1,
                          expands: false,
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF120E1C).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              AnimatedBuilder(
                                animation: _voiceAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _voiceAnimation.value,
                                    child: Icon(
                                      Icons.mic,
                                      color: _isListening
                                          ? Colors.red
                                          : const Color(0xFF4EE0FF),
                                      size: 24,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isListening
                                      ? 'Listening...'
                                      : 'Tap to speak',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    // Voice mode toggle button
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _isVoiceMode
                                ? const Color(0xFFB565FF)
                                : const Color(0xFF4EE0FF),
                            _isVoiceMode
                                ? const Color(0xFF4EE0FF)
                                : const Color(0xFFB565FF),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isVoiceMode ? Icons.mic : Icons.text_fields,
                          color: Colors.black,
                        ),
                        onPressed: () =>
                            setState(() => _isVoiceMode = !_isVoiceMode),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send button
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF4EE0FF),
                            const Color(0xFFB565FF),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        onPressed: _isListening
                            ? null
                            : () => _sendMessage(isVoice: _isVoiceMode),
                        icon: Icon(
                          _isVoiceMode ? Icons.mic : Icons.send,
                          color: Colors.black,
                        ),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
