import 'package:flutter/material.dart';
import '../../data/models/chat_message.dart';
import '../../data/services/chat_service.dart';
import '../widgets/message_bubble.dart';
import 'package:flutter/scheduler.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ChatService _chatService = ChatService();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String _selectedModel = 'llama3.2'; // Default fast model

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userMessage = _controller.text;
    setState(() {
      _messages.add(ChatMessage(content: userMessage, isUser: true));
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final response = await _chatService.sendMessage(
        userMessage,
        model: _selectedModel,
      );
      setState(() {
        _messages.add(
          ChatMessage(content: response, isUser: false, model: _selectedModel),
        );
      });
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            content: "Error: Failed to get response.",
            isUser: false,
            model: "System",
          ),
        );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AI Chat', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          DropdownButton<String>(
            value: _selectedModel,
            dropdownColor: Colors.grey[900],
            style: const TextStyle(color: Colors.white),
            underline: Container(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
            onChanged: (String? newValue) {
              setState(() {
                _selectedModel = newValue!;
              });
            },
            items: <String>['llama3.2', 'llama3'].map<DropdownMenuItem<String>>(
              (String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value == 'llama3.2'
                        ? 'Llama 3.2 (Fast)'
                        : 'Llama 3 (Smart)',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              },
            ).toList(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              padding: const EdgeInsets.only(bottom: 16, top: 16),
              itemBuilder: (context, index) {
                return MessageBubble(message: _messages[index]);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(
                color: Colors.blueAccent,
                backgroundColor: Colors.grey,
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _isLoading ? Colors.grey : Colors.blueAccent,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
