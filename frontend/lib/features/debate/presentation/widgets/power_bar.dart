import 'package:flutter/material.dart';

class PowerBar extends StatelessWidget {
  final double scoreA;
  final double scoreB;

  const PowerBar({super.key, required this.scoreA, required this.scoreB});

  @override
  Widget build(BuildContext context) {
    final total = scoreA + scoreB;
    if (total == 0) return const SizedBox.shrink();

    final percentA = scoreA / total;

    return Container(
      height: 30,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Row(
          children: [
            // Side A
            Expanded(
              flex: (percentA * 100).toInt(),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Purple
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  '${(percentA * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            // Side B
            Expanded(
              flex: 100 - (percentA * 100).toInt(),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00B4DB), Color(0xFF0083B0)], // Cyan
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '${(100 - (percentA * 100).toInt())}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
