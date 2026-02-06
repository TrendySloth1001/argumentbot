import 'package:flutter/material.dart';
import '../../data/models/debate.dart';
import '../../data/services/debate_service.dart';
import '../widgets/power_bar.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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
      String fullContent = '';

      // Temporary turn for UI visualization
      DebateTurn? tempTurn;

      await for (final event in _debateService.streamTurn(widget.debateId)) {
        if (event.containsKey('done')) {
          _loadDebate(); // Reload full debate with analysis when done
          break;
        }

        if (event.containsKey('content')) {
          final content = event['content'];
          final speaker = event['speaker'];
          fullContent += content;

          setState(() {
            // Create or update temporary turn
            if (tempTurn == null) {
              tempTurn = DebateTurn(
                id: 'temp',
                speaker: speaker,
                content: fullContent,
                timestamp: DateTime.now(),
                modelName: 'llama3.2',
              );
              _debate!.turns.add(tempTurn!);
            } else {
              // Update existing temp turn in list (hacky but works for UI)
              _debate!.turns.last = DebateTurn(
                id: 'temp',
                speaker: speaker,
                content: fullContent,
                timestamp: DateTime.now(),
                modelName: 'llama3.2',
              );
            }
          });
          _scrollToBottom();
        }
      }
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
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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

    // Calculate Scores based on analysis
    double scoreA = 50;
    double scoreB = 50;

    for (var turn in _debate!.turns) {
      final analysis = turn.analysis;
      if (analysis != null) {
        final persuasiveness = (analysis['persuasiveness'] ?? 50) as num;
        if (turn.speaker == 'MODEL_A') {
          scoreA += persuasiveness.toDouble();
        } else {
          scoreB += persuasiveness.toDouble();
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              _debate!.topic,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14, // Smaller title to make room
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 20,
              width: 200,
              child: PowerBar(scoreA: scoreA, scoreB: scoreB),
            ),
          ],
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
              Row(
                children: [
                  Text(
                    isModelA ? 'PROPONENT' : 'OPPONENT',
                    style: TextStyle(
                      color: isModelA
                          ? const Color(0xFF8E2DE2)
                          : const Color(0xFF00B4DB),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      turn.modelName ?? 'Llama 3.2', // Show Model Name
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MarkdownBody(
                data: turn.content,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.6,
                    fontFamily: 'Roboto',
                  ),
                  h2: const TextStyle(
                    // Style for ## Answer
                    color: Colors.lightGreenAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 2.0,
                  ),
                  h3: const TextStyle(
                    // Style for ### Counter Question
                    color: Colors.amberAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 2.0,
                  ),
                  listBullet: const TextStyle(color: Colors.white),
                ),
              ),
              if (turn.analysis != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    if (turn.analysis!['key_point'] != null)
                      AnalysisTag(
                        icon: Icons.lightbulb_outline,
                        text: turn.analysis!['key_point'] ?? '',
                        color: Colors.amberAccent,
                      ),
                    if ((turn.analysis!['persuasiveness'] ?? 0) > 80)
                      const AnalysisTag(
                        icon: Icons.local_fire_department,
                        text: 'Strong Point',
                        color: Colors.redAccent,
                      ),
                  ],
                ),
              ],
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

class AnalysisTag extends StatefulWidget {
  final IconData icon;
  final String text;
  final Color color;

  const AnalysisTag({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  State<AnalysisTag> createState() => _AnalysisTagState();
}

class _AnalysisTagState extends State<AnalysisTag> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: widget.color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.icon, color: widget.color, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                widget.text,
                style: TextStyle(
                  color: widget.color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: _isExpanded ? null : 1, // Toggle maxLines
                overflow: _isExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
