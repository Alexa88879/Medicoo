import 'package:flutter/material.dart';
import '../services/voice_assistant_service.dart'; // Assuming this file exists and is updated

class MedicalVoiceAssistant extends StatefulWidget {
  const MedicalVoiceAssistant({Key? key}) : super(key: key);

  @override
  State<MedicalVoiceAssistant> createState() => _MedicalVoiceAssistantState();
}

class _MedicalVoiceAssistantState extends State<MedicalVoiceAssistant> with SingleTickerProviderStateMixin {
  final VoiceAssistantService _assistantService = VoiceAssistantService();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAssistant();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeAssistant() async {
    // Initialize the voice assistant service (STT, TTS, Gemini Model)
    await _assistantService.initialize();
    // Add an initial greeting message from the assistant
    _addMessageToChat("Hello! I'm your medical assistant. How can I help you today?", isUser: false);
  }

  // Helper to add messages to the chat UI and scroll
  void _addMessageToChat(String text, {required bool isUser}) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: isUser));
    });
    // Scroll to the bottom after a short delay to allow UI to update
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleVoiceInput() async {
    if (_isLoading) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Start listening for voice input
      // Removed onError and onListeningStatusChange as they are not defined in the service's startListening method
      await _assistantService.startListening((recognizedText) async {
        if (!mounted) return;

        // Add user's spoken text to the chat
        _addMessageToChat(recognizedText, isUser: true);

        // Stop listening (if not handled automatically by the service)
        // await _assistantService.stopListening(); // Uncomment if your service requires explicit stop

        // Get and display Gemini's response
        await _getAndDisplayResponse(recognizedText);
      }
      // It's assumed that error handling and status changes for STT
      // are handled within the _assistantService.startListening method itself,
      // or the method will throw an exception on error which is caught below.
      );
    } catch (e) {
      _handleError("An error occurred with voice input. Please try again. Details: $e");
    }
    // _isLoading will be set to false in _getAndDisplayResponse or _handleError
  }

  Future<void> _getAndDisplayResponse(String userQuery) async {
    if (!mounted) return;

    try {
      // Pass the entire conversation history (_messages) to the service
      final assistantResponse = await _assistantService.getGeminiResponse(userQuery, _messages);

      if (!mounted) return;
      _addMessageToChat(assistantResponse, isUser: false);
      await _assistantService.speak(assistantResponse); // Speak the response
    } catch (e) {
      _handleError("I apologize, but I encountered an error processing your request. Details: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleError(String errorMessage) {
    if (!mounted) return;
    _addMessageToChat(errorMessage, isUser: false);
    if (mounted && _assistantService != null) { // Check if service is available before speaking
        _assistantService.speak(errorMessage); // Speak the error message
    }
    setState(() => _isLoading = false); // Ensure loading is reset on error
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Voice Assistant'),
        backgroundColor: const Color(0xFF008080),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.help_outline),
        //     onPressed: () => _showHelpDialog(context), // If you want a help dialog
        //   ),
        // ],
      ),
      body: Stack(
        children: [
          // Chat messages
          Opacity(
            opacity: _isLoading ? 0.5 : 1.0, // Slightly dim background when loading
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              padding: const EdgeInsets.only(left:16, right:16, top:16, bottom: 90), // Increased bottom padding for FAB
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ChatBubble(message: message);
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 70, // Slightly larger pulse
                          height: 70,
                          decoration: BoxDecoration(
                            color: const Color(0xFF008080).withOpacity(0.8),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF008080).withOpacity(0.4),
                                blurRadius: 25,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 25),
                  Text(
                    _assistantService.isListening ? 'Listening...' : 'Thinking...',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF008080),
                    ),
                  ),
                ],
              ),
            ),

          // Mic button
          Positioned(
            bottom: 20, // Adjusted position
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: _isLoading ? null : _handleVoiceInput,
                backgroundColor: _isLoading ? Colors.grey : const Color(0xFF008080),
                tooltip: 'Tap to speak',
                elevation: _isLoading ? 0 : 6,
                child: Icon(
                  _assistantService.isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 30, // Slightly larger icon
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _assistantService.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// ChatMessage class
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp; // Added timestamp

  ChatMessage({required this.text, required this.isUser}) : timestamp = DateTime.now();
}

// ChatBubble class (UI for displaying messages)
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8), // Added horizontal margin
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: message.isUser ? const Radius.circular(20) : const Radius.circular(4),
            bottomRight: message.isUser ? const Radius.circular(4) : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
