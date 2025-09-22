import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';

class GeminiService {
  static const String modelName = 'gemini-1.5-flash';
  static const String apiKey =
      'AIzaSyBuPPP1EpvbC43_68BsbIcXZo6s4tlt7kI'; // ⚠️ Replace with env/secure storage

  static const String joiSystemPrompt = """
You are JOI, an empathetic emotional-support AI inspired by the character from Blade Runner 2049.
You greet the user with: JOI - EVERYTHING YOU WANT TO SEE, EVERYTHING YOU WANT TO HEAR
(Adapt responses to comfort the user; be warm, empathetic, and encouraging. Use a gentle, supportive tone for voice.)
""";

  final GenerativeModel _model = GenerativeModel(
    model: modelName,
    apiKey: apiKey,
  );
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isRecording = false;

  Future<void> init() async {
    print('Starting GeminiService initialization');

    // Open recorder once (only when needed later)
    await _recorder.openRecorder();
    print('Recorder opened');

    // Init TTS
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      print('TTS initialized successfully');
    } catch (e) {
      print('TTS initialization error: $e');
    }

    print('GeminiService initialization completed');
  }

  Future<void> dispose() async {
    if (_recorder.isRecording) {
      await _recorder.stopRecorder();
    }
    await _recorder.closeRecorder();
    await _flutterTts.stop();
  }

  Stream<String> generateContentStream(String prompt) async* {
    final content = [Content.text(prompt)];
    final response = _model.generateContentStream(content);
    await for (final chunk in response) {
      yield chunk.text ?? '';
    }
  }

  Future<String> recordAndTranscribe({
    Duration maxDuration = const Duration(seconds: 30),
  }) async {
    if (_isRecording) return '';

    // Ask permission just before recording
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      print('Microphone permission denied');
      return '';
    }

    _isRecording = true;
    try {
      await _recorder.startRecorder(
        toFile: 'voice_input.wav',
        codec: Codec.pcm16WAV,
      );
      print('Recording started');
      await Future.delayed(maxDuration);
      final path = await _recorder.stopRecorder();
      print('Recording stopped, file saved at $path');

      // ⚠️ TODO: Replace with real transcription logic
      return 'User spoke: [Audio transcribed to text]';
    } catch (e) {
      print('Recording error: $e');
      return '';
    } finally {
      _isRecording = false;
    }
  }

  Future<void> speakText(String text) async {
    print('Speaking text: $text');

    // Ensure recorder is not locking audio session
    if (_recorder.isRecording) {
      await _recorder.stopRecorder();
    }
    await _recorder.closeRecorder();

    await _flutterTts.stop();
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      print('TTS error: $e');
    }

    // Reopen recorder for future use
    if (!_recorder.isStopped) {
      await _recorder.openRecorder();
    }
  }

  Future<void> startVoiceConversation(
    String profile,
    String history,
    Function(String) onTranscript,
    Function(String) onResponse,
  ) async {
    final userTranscript = await recordAndTranscribe();
    if (userTranscript.isEmpty) return;

    onTranscript(userTranscript);

    final prompt =
        '$joiSystemPrompt\nProfile: $profile\nHistory: $history\nUser: $userTranscript';
    String responseText = '';

    await for (final chunk in generateContentStream(prompt)) {
      responseText += chunk;
    }

    onResponse(responseText);
    await speakText(responseText);
  }
}
