import 'package:flutter/material.dart';
import '../../../../core/services/socket_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:record/record.dart';
import 'dart:convert';
import 'dart:async';

class DebateRoomScreen extends StatefulWidget {
  final String debateId;
  final String role; // 'PRO' or 'CON'
  final String opponentName;
  final String topic;
  final String currentUserId;

  const DebateRoomScreen({
    super.key,
    required this.debateId,
    required this.role,
    required this.opponentName,
    required this.topic,
    required this.currentUserId,
  });

  @override
  State<DebateRoomScreen> createState() => _DebateRoomScreenState();
}

class _DebateRoomScreenState extends State<DebateRoomScreen> {
  final SocketService _socketService = SocketService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _turns = [];
  bool _isMyTurn = false;
  Map<String, dynamic>? _lastAnalysis;
  bool _isOpponentTyping = false;
  final Color _primaryColor = const Color(0xFF00FF88);

  // STT
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isListening = false;

  // Store subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _socketService.joinDebateRoom(widget.debateId, widget.currentUserId);

    // Pro starts first
    _isMyTurn = widget.role == 'PRO';

    _subscriptions.add(
      _socketService.onNewTurn.listen((data) {
        if (!mounted) return;
        setState(() {
          _turns.add(data);
          _isMyTurn = data['userId'] != widget.currentUserId;
          _isOpponentTyping = false;
        });
        _scrollToBottom();
      }),
    );

    _subscriptions.add(
      _socketService.onScoreUpdate.listen((data) {
        if (!mounted) return;
        setState(() {
          _lastAnalysis = data['analysis'];
        });
      }),
    );

    _subscriptions.add(
      _socketService.onOpponentTyping.listen((status) {
        if (!mounted) return;
        setState(() {
          _isOpponentTyping = status == 'typing';
        });
      }),
    );

    _subscriptions.add(
      _socketService.onSttResult.listen((message) {
        print("DebateRoom: STT Message received: $message");
        try {
          final data = jsonDecode(message);
          if (data['text'] != null) {
            setState(() {
              _textController.text = data['text'];
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: _textController.text.length),
              );
            });
          }
        } catch (e) {
          print("DebateRoom: Error parsing STT: $e");
        }
      }),
    );

    _textController.addListener(_onTyping);
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final stream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );

        setState(() => _isListening = true);

        stream.listen((data) {
          _socketService.sendAudioChunk(data);
        });
      }
    } catch (e) {
      print("Error starting record: $e");
    }
  }

  Future<void> _stopRecording() async {
    await _audioRecorder.stop();
    setState(() => _isListening = false);
  }

  void _onTyping() {
    // Debounce logic could be added here
    _socketService.sendTyping(
      widget.debateId,
      widget.currentUserId,
      _textController.text.isNotEmpty,
    );
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

  void _submitTurn() {
    if (_textController.text.trim().isEmpty) return;

    final content = _textController.text;
    _textController.clear();

    _socketService.submitTurn(
      widget.debateId,
      widget.currentUserId,
      content,
      widget.role == 'PRO' ? 'MODEL_A' : 'MODEL_B',
    );

    setState(() => _isMyTurn = false); // Lock input immediately
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions to prevent memory leaks
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _socketService.leaveDebateRoom(widget.debateId);
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Widget _buildAnalysisCard() {
    if (_lastAnalysis == null) return const SizedBox.shrink();

    final score = _lastAnalysis!['persuasiveness'] ?? 0;
    final comment = _lastAnalysis!['key_point'] ?? 'Analyzing...';

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        border: Border(left: BorderSide(color: _primaryColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel, color: _primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                "AI JUDGE: $score/100",
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            comment,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "LIVE DEBATE",
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "vs ${widget.opponentName}",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: _isMyTurn ? _primaryColor : Colors.grey,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isMyTurn ? "YOUR TURN" : "WAITING...",
              style: TextStyle(
                color: _isMyTurn ? _primaryColor : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Topic Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Text(
              widget.topic,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          if (_lastAnalysis != null) _buildAnalysisCard(),

          // Chat Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _turns.length,
              itemBuilder: (context, index) {
                final turn = _turns[index];
                final isMe = turn['userId'] == widget.currentUserId;
                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isMe
                          ? _primaryColor.withOpacity(0.1)
                          : Colors.grey[800],
                      border: Border.all(
                        color: isMe
                            ? _primaryColor.withOpacity(0.5)
                            : Colors.transparent,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: isMe
                            ? const Radius.circular(12)
                            : Radius.zero,
                        bottomRight: isMe
                            ? Radius.zero
                            : const Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMe ? "You" : widget.opponentName,
                          style: TextStyle(
                            color: isMe ? _primaryColor : Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        MarkdownBody(
                          data: turn['content'],
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isOpponentTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${widget.opponentName} is typing...",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: _isMyTurn,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 4,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? "Listening..."
                          : (_isMyTurn
                                ? "Type your argument..."
                                : "Waiting for opponent..."),
                      hintStyle: TextStyle(
                        color: _isListening ? _primaryColor : Colors.grey[600],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.black,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Mic Button
                AvatarGlow(
                  animate: _isListening,
                  glowColor: _primaryColor,
                  glowRadiusFactor: 0.4, // Adjusted for new API
                  duration: const Duration(milliseconds: 2000),
                  repeat: true,
                  child: IconButton(
                    onPressed: _isMyTurn
                        ? (_isListening ? _stopRecording : _startRecording)
                        : null,
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isMyTurn
                          ? (_isListening ? _primaryColor : Colors.grey[400])
                          : Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isMyTurn ? _submitTurn : null,
                  icon: Icon(
                    Icons.send,
                    color: _isMyTurn ? _primaryColor : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
