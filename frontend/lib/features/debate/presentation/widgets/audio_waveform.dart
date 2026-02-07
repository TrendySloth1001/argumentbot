import 'dart:math';
import 'package:flutter/material.dart';

class AudioWaveform extends StatefulWidget {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final Color color;

  const AudioWaveform({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.color,
  });

  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying) return const SizedBox.shrink();

    return SizedBox(
      height: 24, // Fixed height for the bar
      width: double.infinity, // Full width
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _WaveformPainter(
              progress: (widget.duration.inMilliseconds > 0)
                  ? widget.position.inMilliseconds /
                        widget.duration.inMilliseconds
                  : 0.0,
              animationValue: _controller.value,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final double animationValue;
  final Color color;

  _WaveformPainter({
    required this.progress,
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    // Configuration
    const barWidth = 3.0;
    const gap = 2.0;
    final totalBarWidth = barWidth + gap;
    final count = (size.width / totalBarWidth).floor();

    // We want the waveform to be roughly symmetric around the center of the available width
    // But since it's a progress bar, maybe just uniform?
    // The user liked the "animation" from the image (symmetric).
    // Let's do a symmetric shape centered in the width.

    // Calculate how many bars fit
    // If we want it to span FULL width, we distribute bars across width.

    for (int i = 0; i < count; i++) {
      // x position
      double x = i * totalBarWidth + (size.width - (count * totalBarWidth)) / 2;

      // Normalized position (-1 to 1) for symmetry
      double normalizedPos = (i - (count / 2)) / (count / 2);

      // Base height shape (bell curve-ish)
      // 1.0 at center, 0.3 at edges
      double baseHeightRatio = 1.0 - (normalizedPos.abs() * 0.7);

      // Animation
      // Wave moving left to right? or Standing wave?
      // Standing wave breathing is nice.
      double t = animationValue * 2 * pi;
      double noise = sin(t + i * 0.2) * 0.2;
      double jitter = Random(i).nextDouble() * 0.1;

      double heightRatio = (baseHeightRatio + noise + jitter).clamp(0.1, 1.0);
      double barHeight = heightRatio * size.height;

      // Progress Coloring
      // Map i to 0..1
      double barProgress = i / count;
      bool isActive = barProgress <= progress;

      paint.color = isActive ? color : color.withOpacity(0.2);

      // Draw centered vertically
      double y = (size.height - barHeight) / 2;

      // Rounded rect
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}
