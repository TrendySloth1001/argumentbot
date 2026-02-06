import 'package:flutter/material.dart';
import '../../data/models/debate.dart';
import '../../data/services/debate_service.dart';

class DebateScreen extends StatefulWidget {
  final String debateId;

  const DebateScreen({super.key, required this.debateId});

  @override
  State<DebateScreen> createState() => _DebateScreenState();
}

class _DebateScreenState extends State<DebateScreen> {
  final _debateService = DebateService();
  Debate? _debate;
  bool _isLoading = true;
  bool _isProcessingTurn = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadDebate();
  }

  Future<void> _loadDebate() async {
    try {
      final debate = await _debateService.getDebate(widget.debateId);
      setState(() {
        _debate = debate;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      // Handle error gracefully
    }
  }

  Future<void> _nextTurn() async {
    if (_isProcessingTurn) return;
    setState(() {
      _isProcessingTurn = true;
    });

    try {
      final debate = await _debateService.nextTurn(widget.debateId);
      setState(() {
        _debate = debate;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isProcessingTurn = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_debate == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Failed to load debate',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black, // Premium Dark Background
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _debate!.topic,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_debate!.status != 'FINISHED')
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.grey[400]),
              onPressed: _loadDebate,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _debate!.turns.length,
              itemBuilder: (context, index) {
                final turn = _debate!.turns[index];
                final isModelA = turn.speaker == 'MODEL_A';

                return _buildMessageBubble(turn, isModelA);
              },
            ),
          ),
          _buildBottomControl(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(DebateTurn turn, bool isModelA) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isModelA ? 'PROPONENT (AI)' : 'OPPONENT (AI)',
                style: TextStyle(
                  color: isModelA
                      ? const Color(0xFF8E2DE2)
                      : const Color(0xFF00B4DB),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                turn.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.6,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        ),
        Divider(color: Colors.grey[900], thickness: 1),
      ],
    );
  }

  Widget _buildBottomControl() {
    if (_debate!.status == 'FINISHED') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.greenAccent,
              size: 40,
            ),
            const SizedBox(height: 10),
            const Text(
              'Debate Concluded',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'This session has ended.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.black, // Blend with background
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isProcessingTurn ? null : _nextTurn,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 10,
            shadowColor: Colors.white24,
          ),
          child: _isProcessingTurn
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Trigger Counter-Argument',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}
