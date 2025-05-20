import 'package:flutter/material.dart';
import '../services/voice_assistant_service.dart';

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
    await _assistantService.initialize();
    _addAssistantMessage("Hello! I'm your medical assistant. How can I help you today?");
  }

  void _addAssistantMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: false));
    });
    _scrollToBottom();
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
    
    setState(() => _isLoading = true);
    
    try {
      await _assistantService.startListening((text) async {
        setState(() {
          _messages.add(ChatMessage(text: text, isUser: true));
        });
        _scrollToBottom();
        
        await _assistantService.stopListening();
        
        _getAndDisplayResponse(text);
      });
    } catch (e) {
      _handleError("Sorry, I couldn't hear you. Please try again.");
    }
  }

  Future<void> _getAndDisplayResponse(String query) async {
    try {
      final response = await _assistantService.getGeminiResponse(query);
      
      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
      
      await _assistantService.speak(response);
    } catch (e) {
      _handleError("I apologize, but I encountered an error. Please try again.");
    }
  }

  void _handleError(String message) {
    setState(() {
      _messages.add(ChatMessage(text: message, isUser: false));
      _isLoading = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Voice Assistant'),
        backgroundColor: const Color(0xFF008080),
        actions: [
          /*//IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),*/
        ],
      ),
      body: Stack(
        children: [
          // Chat messages
          Opacity(
            opacity: _isLoading ? 0.3 : 1.0,
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              padding: const EdgeInsets.all(16),
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
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF008080),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF008080).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _assistantService.isListening ? 'Listening...' : 'Processing...',
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
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: _isLoading ? null : _handleVoiceInput,
                backgroundColor: const Color(0xFF008080),
                child: Icon(
                  _assistantService.isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 28,
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

// Update the getGeminiResponse method in VoiceAssistantService


class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

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
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFF008080) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
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