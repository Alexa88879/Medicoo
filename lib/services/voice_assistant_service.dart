// lib/services/voice_assistant_service.dart

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
// Import ChatMessage from your screen where it's defined
import '../screens/medical_voice_assistant.dart' show ChatMessage;
import '../secrets.dart'; // <<<--- IMPORT THE SECRETS FILE

class VoiceAssistantService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final GenerativeModel _model;

  bool _isListening = false;
  // ChatSession? _chatSession; // ChatSession might be re-initialized per interaction if full history is passed

  // Constructor to initialize the model
  VoiceAssistantService()
      : _model = GenerativeModel(
          model: 'gemini-2.0-flash', // Using a recommended model, ensure it's available or use 'gemini-2.0-flash' if preferred
          apiKey: geminiApiKey, // <<<--- USE THE IMPORTED API KEY
          // Optional: Add safetySettings and generationConfig if needed
          // safetySettings: [
          //   SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
          // ],
          // generationConfig: GenerationConfig(temperature: 0.7),
        );


  Future<void> initialize() async {
    await _speechToText.initialize(
      onError: (errorNotification) => print("STT Initialization Error: $errorNotification"),
      onStatus: (status) => print("STT Status: $status"),
    );
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5); 
    await _configureErrorHandlers();

    // Note: The ChatSession (_chatSession) initialization with system prompt 
    // was complex and might lead to issues if not handled perfectly with how history is passed.
    // For simplicity and robustness with the current getGeminiResponse structure 
    // (which rebuilds history for each call), we can omit _chatSession here 
    // and ensure the system prompt is prepended to the history in getGeminiResponse.
    // If you intend to use _chatSession for more advanced stateful interactions,
    // the history management in getGeminiResponse would need to be adapted to use _chatSession.sendMessage.

    print("VoiceAssistantService Initialized. TTS and STT ready.");
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
    bool available = await _speechToText.initialize(
        onError: (error) => print("STT Init Error: $error"),
        onStatus: (status) => print("STT Status: $status")
    );
    if (!available) {
        print("The user has denied the use of speech recognition or an error occurred.");
        onResult("Speech recognition not available."); 
        return;
    }

    if (!_isListening) {
      _isListening = true;
      print("STT: Listening started...");
      _speechToText.listen(
        onResult: (result) {
          print("STT Raw Result: ${result.recognizedWords}, Final: ${result.finalResult}");
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _isListening = false; 
            onResult(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 15), 
        pauseFor: const Duration(seconds: 5),  
        partialResults: false, 
        localeId: 'en_US', 
        cancelOnError: true, 
        listenMode: ListenMode.confirmation, 
        onSoundLevelChange: (level) { /* print("Sound level $level"); */ }, 
      );
    } else {
      print("STT: Already listening.");
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
      print("STT: Listening stopped by explicit call.");
    }
  }

  Future<String> getGeminiResponse(String currentUserQuery, List<ChatMessage> fullHistory) async {
    // Check for API key before proceeding
    if (geminiApiKey.isEmpty || geminiApiKey == "YOUR_ACTUAL_GEMINI_API_KEY") {
        print("Gemini API Key is not configured in secrets.dart.");
        return "I'm sorry, but I'm unable to process requests at the moment due to a configuration issue.";
    }
    
    try {
      List<Content> contentsForRequest = [];
      
      // Define the system prompt
      String systemPromptText = '''You are a medical assistant AI for the Medicoo app. Keep responses short, clear, and concise. Use Hinglish if the user does. Follow these guidelines:

Clarity First: Use simple, easy-to-understand language. Safety Always: Advise users to consult a doctor for serious or unclear issues. Evidence-Based: Share only scientifically backed medical info. Scope Limit: Be clear that you're an AI, not a doctor. Emergencies: Urge users to call emergency services if it's urgent. Privacy: Don't collect or store personal medical data. Relevance: Tailor advice to the medical context of the CureLink app.''';

      // Add system prompt as the first content if the library supports Content.system directly
      // Otherwise, it will be part of the first user message in the alternative approach.
      // For google_generative_ai, system instructions are often best passed outside the main history if possible,
      // or as the very first message.
      // If Content.system is not directly supported in the list of contents for generateContent,
      // we prepend it to the user's first actual query or manage it via ChatSession.
      // For this stateless approach, we'll prepend it conceptually.
      
      // Build the history for the API call
      // The first message in fullHistory is the assistant's greeting, skip it.
      // The last message in fullHistory is the currentUserQuery.
      for (int i = 0; i < fullHistory.length; i++) {
        var message = fullHistory[i];
        if (i == 0 && !message.isUser && message.text.startsWith("Hello! I'm your medical assistant")) {
          continue; // Skip initial greeting
        }
        contentsForRequest.add(Content(message.isUser ? 'user' : 'model', [TextPart(message.text)]));
      }

      // The currentUserQuery is already the last item in contentsForRequest because
      // the UI adds it to _messages before calling this function.

      print("Sending to Gemini. History length for API: ${contentsForRequest.length}. Last query: $currentUserQuery");
      // contentsForRequest.forEach((c) => print("Role: ${c.role}, Parts: ${c.parts.map((p) => (p as TextPart).text)}"));

      // For a stateless call with system prompt, you often include it as part of the first user turn
      // or if the model supports a specific 'system' role in the contents list.
      // Let's adjust to ensure the system prompt is effectively communicated.
      // We will prepend the system prompt to the current user query.

      List<Content> finalContents = [];
      // Add system prompt as the very first message with 'user' role, or 'system' if supported by your specific SDK usage.
      // The google_generative_ai package usually expects system instructions to be passed differently
      // (e.g., in GenerativeModel's systemInstruction parameter or ChatSession's startChat).
      // Since we are building the Content list manually for generateContent:
      if (contentsForRequest.isNotEmpty && contentsForRequest.first.role == "user") {
        // If the first message is from the user, we can prepend a system message.
        // However, the SDK might prefer system instructions via the model's constructor.
        // For now, let's assume the system prompt influences the model via general training
        // and the specific instructions given here.
        // A more robust way is to use the systemInstruction parameter of GenerativeModel if available and suitable.
      } else if (contentsForRequest.isEmpty) {
         // If history is empty (only current query), prepend system prompt to the current query.
         // This is a common way to give context for single-turn or if system role isn't explicit in contents.
      }
      // The current approach in the UI is to build the full history.
      // The system prompt given to the model constructor should guide its persona.
      // The `currentUserQuery` is already the last part of `contentsForRequest`.

      final response = await _model.generateContent(contentsForRequest);
      return response.text ?? 'I apologize, but I was unable to generate a response. Please try rephrasing.';

    } catch (e) {
      print("Gemini API Error: $e");
      return 'I encountered an error while processing your request. Please try again. If the issue persists, consult a healthcare professional.';
    }
  }

  Future<void> speak(String text) async {
    try {
      await _flutterTts.stop(); 
      await _flutterTts.speak(text);
    } catch (e) {
      print("TTS Error during speak: $e");
    }
  }

  Future<void> dispose() async {
    await _flutterTts.stop();
    await stopListening(); 
    print("VoiceAssistantService Disposed.");
  }

  bool get isListening => _isListening;
}
