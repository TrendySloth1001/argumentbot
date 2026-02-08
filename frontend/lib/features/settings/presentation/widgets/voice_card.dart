import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/data/voice_settings.dart';

class VoiceCard extends StatefulWidget {
  final VoiceModel voice;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPreview;

  const VoiceCard({
    super.key,
    required this.voice,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
    required this.onPreview,
  });

  @override
  State<VoiceCard> createState() => _VoiceCardState();
}

class _VoiceCardState extends State<VoiceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPlaying) {
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(VoiceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _waveController.repeat();
      } else {
        _waveController.stop();
        _waveController.reset();
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Neon Green Theme for all cards
    const themeColor = Color(0xFF00FF88);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? themeColor.withOpacity(0.1)
              : Colors.grey[900]?.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected ? themeColor : Colors.grey[800]!,
            width: widget.isSelected ? 1.5 : 1,
          ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: themeColor.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Background Gradient for selected
              if (widget.isSelected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          themeColor.withOpacity(0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Play/Pause Button with Waveform
                    GestureDetector(
                      onTap: widget.onPreview,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: widget.isPlaying
                              ? _WaveformVisualizer(
                                  color: themeColor,
                                  waveController: _waveController,
                                )
                              : Icon(
                                  Icons.play_arrow_rounded,
                                  color: themeColor,
                                  size: 28,
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.voice.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: themeColor,
                                  size: 18,
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildBadge(
                                widget.voice.engine == 'coqui' ? 'PRO' : 'FAST',
                                themeColor,
                              ),
                              const SizedBox(width: 8),
                              _buildBadge(widget.voice.gender, Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.voice.accent,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _WaveformVisualizer({
    required Color color,
    required AnimationController waveController,
  }) {
    return AnimatedBuilder(
      animation: waveController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final value = sin((waveController.value * 2 * pi) + (index * 1.5));
            final height = 12.0 + (value * 8.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color.withOpacity(0.9),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
