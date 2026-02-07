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
  final int _barCount = 30;

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

    final progress = (widget.duration.inMilliseconds > 0)
        ? widget.position.inMilliseconds / widget.duration.inMilliseconds
        : 0.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_barCount, (index) {
            // Symmetric shape: taller in center
            // index 0..29. Center is 14.5.
            double dist = (index - (_barCount / 2)).abs() / (_barCount / 2);
            double baseHeight =
                (1.0 - dist * 0.8); // 1.0 at center, 0.2 at edges

            // Animation noise
            double t = _controller.value * 2 * pi;
            double noise = sin(t + index * 0.5) * 0.2;

            // Random jitter for "voice" feel
            double jitter =
                Random(index + DateTime.now().millisecond).nextDouble() * 0.1;

            double heightFactors = (baseHeight + noise + jitter).clamp(
              0.1,
              1.0,
            );
            double height = heightFactors * 24.0; // Max height 24

            // Progress coloring
            // Map index to 0..1 range
            double barPos = index / _barCount;
            bool isActive = barPos <= progress;

            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: isActive ? widget.color : widget.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}
