import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/services/tts_service.dart';
import 'dart:math';

class VoicePreviewButton extends StatefulWidget {
  final String voiceId;
  final TtsService ttsService;
  final Color color;

  const VoicePreviewButton({
    super.key,
    required this.voiceId,
    required this.ttsService,
    required this.color,
  });

  @override
  State<VoicePreviewButton> createState() => _VoicePreviewButtonState();
}

class _VoicePreviewButtonState extends State<VoicePreviewButton>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  bool _isLoading = false;
  bool _isPlaying = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying =
              state.playing &&
              state.processingState != ProcessingState.completed &&
              state.processingState != ProcessingState.idle;

          if (state.processingState == ProcessingState.completed) {
            _player.stop();
            _player.seek(Duration.zero);
          }
        });

        if (_isPlaying) {
          _animationController.repeat(reverse: true);
        } else {
          _animationController.stop();
          _animationController.reset();
        }
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _playPreview() async {
    if (_isPlaying) {
      await _player.stop();
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Different preview text based on voice gender/style for variety
      // but keeping it simple for now.
      const text = "Hi, I'm ready to debate. Let's verify my voice.";
      final url = widget.ttsService.getStreamUrl(text, voice: widget.voiceId);

      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      print('Preview error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play preview'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _playPreview,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: _isPlaying ? widget.color : widget.color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.color,
                ),
              )
            : _isPlaying
            ? AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBar(0.6),
                      _buildBar(0.8),
                      _buildBar(1.0),
                      _buildBar(0.7),
                    ],
                  );
                },
              )
            : Icon(Icons.play_arrow_rounded, color: widget.color, size: 24),
      ),
    );
  }

  Widget _buildBar(double scaleMultiplier) {
    // Random-ish height based on animation value
    final value = _animationController.value;
    final height =
        12.0 + (value * 12.0 * scaleMultiplier) + (Random().nextDouble() * 4);

    return Container(
      width: 3,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
