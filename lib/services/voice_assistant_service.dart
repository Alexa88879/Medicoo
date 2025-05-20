import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceAssistantService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final GenerativeModel _model = GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: 'AIzaSyAueUuvR5vaeBQIqkaKin0P52P7Np6hMX4', // Replace with your API key
  );
  
  bool _isListening = false;
  
  Future<void> initialize() async {
    await _speechToText.initialize();
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _configureErrorHandlers();
  }
  
  Future<void> _configureErrorHandlers() async {
    _flutterTts.setErrorHandler((msg) {
      print("TTS Error: $msg");
    });
    
    _flutterTts.setStartHandler(() {
      print("TTS Started");
    });
    
    _flutterTts.setCompletionHandler(() {
      print("TTS Completed");
    });
  }
  
  Future<void> startListening(Function(String) onResult) async {
    if (!_isListening && await _speechToText.initialize()) {
      _isListening = true;
      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            onResult(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: false,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
    }
  }
  
  Future<void> stopListening() async {
    _isListening = false;
    await _speechToText.stop();
  }
  
  Future<String> getGeminiResponse(String prompt) async {
    try {
      final enhancedPrompt = '''
You are a medical assistant AI for the Medicoo app. Keep responses short, clear, and concise. Use Hinglish if the user does. Follow these guidelines:

Clarity First: Use simple, easy-to-understand language.

Safety Always: Advise users to consult a doctor for serious or unclear issues.

Evidence-Based: Share only scientifically backed medical info.

Scope Limit: Be clear that you're an AI, not a doctor.

Emergencies: Urge users to call emergency services if it's urgent.

Privacy: Don"t collect or store personal medical data.

Relevance: Tailor advice to the medical context of the Medicoo app.

User Query: $prompt

Please provide a structured, clear response that prioritizes user safety and medical accuracy.
''';

      final content = [Content.text(enhancedPrompt)];
      final response = await _model.generateContent(content);
      return response.text ?? 'I apologize, but I was unable to generate a response. Please try rephrasing your question.';
    } catch (e) {
      return 'I encountered an error while processing your request. Please try again or rephrase your question. If the issue persists, please consult with a healthcare professional directly.';
    }
  }
  
  Future<void> speak(String text) async {
    try {
      await _flutterTts.stop(); // Stop any ongoing speech
      await _flutterTts.speak(text);
    } catch (e) {
      print("TTS Error: $e");
    }
  }
  
  Future<void> dispose() async {
    await _flutterTts.stop();
    await stopListening();
  }
  
  bool get isListening => _isListening;
}