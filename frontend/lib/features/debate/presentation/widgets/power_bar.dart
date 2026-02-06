import 'package:flutter/material.dart';

class PowerBar extends StatelessWidget {
  final double scoreA;
  final double scoreB;
  final bool showPercentages;

  static const Color neonGreen = Color(0xFF00FF88);

  const PowerBar({
    super.key,
    required this.scoreA,
    required this.scoreB,
    this.showPercentages = true,
  });

  @override
  Widget build(BuildContext context) {
    final total = scoreA + scoreB;
    if (total == 0) return const SizedBox.shrink();

    final percentA = (scoreA / total * 100).toInt();
    final percentB = 100 - percentA;

    return Column(
      children: [
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey[850],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                // Side A - Neon Green (Pro)
                Expanded(
                  flex: percentA.clamp(1, 99),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [neonGreen, neonGreen.withAlpha(200)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
                // Side B - Grey (Con)
                Expanded(
                  flex: percentB.clamp(1, 99),
                  child: Container(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
        if (showPercentages) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$percentA%',
                style: const TextStyle(
                  color: neonGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$percentB%',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// Mini version for cards - just the bar, no percentages
class MiniPowerBar extends StatelessWidget {
  final double scoreA;
  final double scoreB;

  static const Color neonGreen = Color(0xFF00FF88);

  const MiniPowerBar({super.key, required this.scoreA, required this.scoreB});

  @override
  Widget build(BuildContext context) {
    final total = scoreA + scoreB;
    if (total == 0) {
      return Container(
        height: 3,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

    final percentA = (scoreA / total * 100).toInt();

    return Container(
      height: 3,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: Colors.grey[800],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Row(
          children: [
            Expanded(
              flex: percentA.clamp(1, 99),
              child: Container(color: neonGreen),
            ),
            Expanded(
              flex: (100 - percentA).clamp(1, 99),
              child: Container(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}
