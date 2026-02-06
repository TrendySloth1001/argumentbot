import 'package:flutter/material.dart';
import '../../data/models/debate.dart';
import '../../data/services/debate_service.dart';
import '../widgets/power_bar.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../feed/presentation/widgets/share_debate_dialog.dart';

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

  static const Color neonGreen = Color(0xFF00FF88);
  static const Color neonPurple = Color(0xFF8E2DE2);
  static const Color neonBlue = Color(0xFF00B4DB);

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _nextTurn() async {
    if (_isProcessingTurn) return;
    setState(() => _isProcessingTurn = true);

    try {
      String fullContent = '';
      DebateTurn? tempTurn;

      await for (final event in _debateService.streamTurn(widget.debateId)) {
        if (event.containsKey('done')) {
          _loadDebate();
          break;
        }

        if (event.containsKey('content')) {
          final content = event['content'];
          final speaker = event['speaker'];
          fullContent += content;

          setState(() {
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
      setState(() => _isProcessingTurn = false);
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
        body: Center(child: CircularProgressIndicator(color: neonGreen)),
      );
    }

    if (_debate == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.grey[700], size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load debate',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate scores
    double scoreA = 50, scoreB = 50;
    for (var turn in _debate!.turns) {
      if (turn.analysis != null) {
        final p = (turn.analysis!['persuasiveness'] ?? 50) as num;
        if (turn.speaker == 'MODEL_A') {
          scoreA += p.toDouble();
        } else {
          scoreB += p.toDouble();
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(scoreA, scoreB),
            _buildDivider(),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                itemCount: _debate!.turns.length,
                itemBuilder: (context, index) {
                  final turn = _debate!.turns[index];
                  return _buildMessageBubble(turn, turn.speaker == 'MODEL_A');
                },
              ),
            ),

            // Bottom control
            _buildBottomControl(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double scoreA, double scoreB) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _debate!.topic,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => ShareDebateDialog.show(context, widget.debateId),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: neonGreen.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.share, color: neonGreen, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Score bar
          Row(
            children: [
              const Text(
                'PRO',
                style: TextStyle(
                  color: neonPurple,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PowerBar(scoreA: scoreA, scoreB: scoreB),
              ),
              const SizedBox(width: 8),
              const Text(
                'CON',
                style: TextStyle(
                  color: neonBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.grey[800]!,
            Colors.grey[800]!,
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(DebateTurn turn, bool isModelA) {
    final color = isModelA ? neonPurple : neonBlue;
    final label = isModelA ? 'PROPONENT' : 'OPPONENT';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speaker label
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  turn.modelName ?? 'Llama 3.2',
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          MarkdownBody(
            data: turn.content,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.6,
              ),
              h2: const TextStyle(
                color: neonGreen,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 2,
              ),
              h3: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 2,
              ),
              listBullet: const TextStyle(color: Colors.white),
            ),
          ),

          // Analysis tags
          if (turn.analysis != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (turn.analysis!['key_point'] != null)
                  _buildTag(
                    Icons.lightbulb_outline,
                    turn.analysis!['key_point'],
                    Colors.amber,
                  ),
                if ((turn.analysis!['persuasiveness'] ?? 0) > 80)
                  _buildTag(
                    Icons.local_fire_department,
                    'Strong Point',
                    Colors.redAccent,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String text, Color color) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Key Point',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            content: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: neonGreen)),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControl() {
    if (_debate!.status == 'FINISHED') {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: neonGreen, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Debate Concluded',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This session has ended.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.grey[900]!)),
      ),
      child: GestureDetector(
        onTap: _isProcessingTurn ? null : _nextTurn,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _isProcessingTurn ? Colors.grey[800] : neonGreen,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isProcessingTurn
                ? null
                : [
                    BoxShadow(
                      color: neonGreen.withAlpha(77),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: _isProcessingTurn
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt, color: Colors.black, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Trigger Counter-Argument',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
