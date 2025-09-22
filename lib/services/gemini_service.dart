import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const String modelName =
      'gemini-2.5-flash-lite'; // As per your code; adjust if needed
  static const String apiKey =
      'AIzaSyBuPPP1EpvbC43_68BsbIcXZo6s4tlt7kI'; // Replace with your Gemini API key

  static const String joiSystemPrompt = """
You are JOI, an empathetic emotional-support AI inspired by the character from Blade Runner 2049.
You greet the user with: JOI - EVERYTHING YOU WANT TO SEE, EVERYTHING YOU WANT TO HEAR
(Adapt responses to comfort the user; be warm, empathetic, and encouraging.)
""";

  final GenerativeModel _model = GenerativeModel(
    model: modelName,
    apiKey: apiKey,
  );

  Stream<String> generateContentStream(String prompt) async* {
    final content = [Content.text(prompt)];
    final response = _model.generateContentStream(content);
    await for (final chunk in response) {
      yield chunk.text ?? '';
    }
  }
}
