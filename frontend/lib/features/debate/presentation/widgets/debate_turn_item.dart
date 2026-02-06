import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../data/models/debate.dart';

class DebateTurnItem extends StatefulWidget {
  final DebateTurn turn;
  final bool isModelA;

  const DebateTurnItem({super.key, required this.turn, required this.isModelA});

  @override
  State<DebateTurnItem> createState() => _DebateTurnItemState();
}

class _DebateTurnItemState extends State<DebateTurnItem> {
  @override
  Widget build(BuildContext context) {
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
                    widget.isModelA ? 'PROPONENT' : 'OPPONENT',
                    style: TextStyle(
                      color: widget.isModelA
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
                      widget.turn.modelName ?? 'Llama 3.2',
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
                data: widget.turn.content,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.6,
                    fontFamily: 'Roboto',
                  ),
                  h2: const TextStyle(
                    color: Colors.lightGreenAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 2.0,
                  ),
                  h3: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 2.0,
                  ),
                  listBullet: const TextStyle(color: Colors.white),
                ),
              ),
              if (widget.turn.analysis != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    if (widget.turn.analysis!['key_point'] != null)
                      AnalysisTag(
                        icon: Icons.lightbulb_outline,
                        text: widget.turn.analysis!['key_point'] ?? '',
                        color: Colors.amberAccent,
                      ),
                    if ((widget.turn.analysis!['persuasiveness'] ?? 0) > 80)
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
                maxLines: _isExpanded ? null : 1,
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
