import 'package:flutter/material.dart';
import '../../data/models/debate.dart';

class DebateResultView extends StatelessWidget {
  final Debate debate;
  final VoidCallback? onClose;
  final bool isEmbedded; // For use inside DebateScreen vs bottom sheet

  const DebateResultView({
    super.key,
    required this.debate,
    this.onClose,
    this.isEmbedded = false,
  });

  static const Color neonGreen = Color(0xFF00FF88);
  static const Color neonPurple = Color(0xFFBB86FC);
  static const Color neonBlue = Color(0xFF4DD0E1);

  Map<String, double> _calculateScores() {
    // Unified score calculation - same as PowerBar
    double scoreA = 50.0;
    double scoreB = 50.0;

    for (var turn in debate.turns) {
      final analysis = turn.analysis;
      if (analysis != null) {
        final persuasiveness = (analysis['persuasiveness'] ?? 0) as num;
        if (turn.speaker == 'MODEL_A') {
          scoreA += persuasiveness.toDouble();
        } else {
          scoreB += persuasiveness.toDouble();
        }
      }
    }

    // Normalize to percentage
    final total = scoreA + scoreB;
    final percentA = total > 0 ? (scoreA / total * 100).toDouble() : 50.0;
    final percentB = total > 0 ? (scoreB / total * 100).toDouble() : 50.0;

    return {
      'scoreA': scoreA,
      'scoreB': scoreB,
      'percentA': percentA,
      'percentB': percentB,
    };
  }

  String _getWinnerSide(Map<String, double> scores) {
    if (scores['scoreA']! > scores['scoreB']!) return 'PRO';
    if (scores['scoreB']! > scores['scoreA']!) return 'CON';
    return 'DRAW';
  }

  String _getWinnerStatement(Map<String, double> scores) {
    final winner = _getWinnerSide(scores);
    final margin = (scores['scoreA']! - scores['scoreB']!).abs();

    // Check for concession
    if (debate.turns.isNotEmpty &&
        debate.turns.last.analysis?['conceded'] == true) {
      final loser = debate.turns.last.speaker == 'MODEL_A' ? 'PRO' : 'CON';
      return '$loser conceded the debate. Victory goes to ${loser == 'PRO' ? 'CON' : 'PRO'}!';
    }

    if (winner == 'DRAW') {
      return 'An incredibly close match! Both sides presented equally compelling arguments.';
    }

    if (margin > 50) {
      return '$winner dominated this debate with overwhelmingly persuasive arguments!';
    } else if (margin > 25) {
      return '$winner wins with a strong lead, presenting more convincing points throughout.';
    } else {
      return '$winner edges out a narrow victory in this closely contested debate.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scores = _calculateScores();
    final winner = _getWinnerSide(scores);
    final statement = _getWinnerStatement(scores);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: isEmbedded
            ? BorderRadius.circular(16)
            : const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isEmbedded) ...[
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Trophy Icon
          const Icon(Icons.emoji_events, color: Colors.amber, size: 48),
          const SizedBox(height: 12),

          // Title
          const Text(
            'DEBATE RESULT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Scores Row
          Row(
            children: [
              Expanded(
                child: _buildScoreColumn(
                  'PRO',
                  scores['scoreA']!,
                  scores['percentA']!,
                  neonGreen,
                  winner == 'PRO',
                ),
              ),
              Container(width: 1, height: 60, color: Colors.grey[800]),
              Expanded(
                child: _buildScoreColumn(
                  'CON',
                  scores['scoreB']!,
                  scores['percentB']!,
                  neonBlue,
                  winner == 'CON',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Winner Statement
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: winner == 'PRO'
                  ? neonGreen.withAlpha(15)
                  : winner == 'CON'
                  ? neonBlue.withAlpha(15)
                  : Colors.grey[850],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: winner == 'PRO'
                    ? neonGreen.withAlpha(50)
                    : winner == 'CON'
                    ? neonBlue.withAlpha(50)
                    : Colors.grey[700]!,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      winner == 'DRAW' ? Icons.handshake : Icons.military_tech,
                      color: winner == 'PRO'
                          ? neonGreen
                          : winner == 'CON'
                          ? neonBlue
                          : Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      winner == 'DRAW' ? 'DRAW' : '$winner WINS!',
                      style: TextStyle(
                        color: winner == 'PRO'
                            ? neonGreen
                            : winner == 'CON'
                            ? neonBlue
                            : Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  statement,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Concession Badge
          if (debate.turns.isNotEmpty &&
              debate.turns.last.analysis?['conceded'] == true) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withAlpha(50)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${debate.turns.last.speaker == 'USER' ? 'YOU' : debate.turns.last.modelName ?? 'AI'} CONCEDED',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Close Button
          if (onClose != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: neonGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isEmbedded ? 'Exit Debate' : 'Close',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreColumn(
    String label,
    double score,
    double percent,
    Color color,
    bool isWinner,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isWinner) Icon(Icons.star, color: Colors.amber, size: 14),
            if (isWinner) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${percent.toStringAsFixed(0)}%',
          style: TextStyle(
            color: isWinner ? Colors.white : Colors.grey[400],
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Score: ${score.toStringAsFixed(0)}',
          style: TextStyle(color: Colors.grey[600], fontSize: 11),
        ),
      ],
    );
  }
}
