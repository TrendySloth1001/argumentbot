import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class KaraokeText extends StatefulWidget {
  final String text;
  final AudioPlayer? audioPlayer;
  final bool isPlaying;
  final List<String>? sentences;
  final int? currentIndex;

  const KaraokeText({
    super.key,
    required this.text,
    this.audioPlayer,
    this.isPlaying = false,
    this.sentences,
    this.currentIndex,
  });

  @override
  State<KaraokeText> createState() => _KaraokeTextState();
}

class _KaraokeTextState extends State<KaraokeText> {
  double _progress = 0.0;
  StreamSubscription<Duration>? _positionStream;
  StreamSubscription<Duration?>? _durationStream;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying && widget.audioPlayer != null) {
      _startListening();
    }
  }

  void _startListening() {
    _positionStream?.cancel();
    _durationStream?.cancel();

    final player = widget.audioPlayer!;
    // Note: With ConcatenatingAudioSource, duration changes per item.
    // player.durationStream emits duration of current item.

    if (player.duration != null) {
      _totalDuration = player.duration!;
    }

    _durationStream = player.durationStream.listen((duration) {
      if (duration != null) {
        if (mounted) setState(() => _totalDuration = duration);
      }
    });

    _positionStream = player.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          // If duration is unknown/streaming, rely on word count estimation for specific sentence?
          // Or just 0..1 if we have duration.
          // ConcatenatingAudioSource usually provides duration if header is valid.
          // Our "synthesize" endpoint (non-stream) returns valid WAV with header.
          // So _totalDuration should be correct.

          if (_totalDuration.inMilliseconds > 0) {
            _progress = position.inMilliseconds / _totalDuration.inMilliseconds;
          } else {
            // Fallback if header issues persist (e.g. streaming chunks)
            // For sentence, we can estimate?
            // But we moved to "synthesize" which generates valid WAV.
            _progress = 0.0;
          }

          if (_progress > 1.0) _progress = 1.0;
          if (_progress < 0.0) _progress = 0.0;
        });
      }
    });
  }

  @override
  void didUpdateWidget(KaraokeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying ||
        widget.audioPlayer != oldWidget.audioPlayer) {
      if (widget.isPlaying && widget.audioPlayer != null) {
        _startListening();
      } else {
        _stopListening();
        setState(() => _progress = 0.0);
      }
    }
  }

  void _stopListening() {
    _positionStream?.cancel();
    _durationStream?.cancel();
    _positionStream = null;
    _durationStream = null;
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying) {
      return RichText(
        text: TextSpan(children: _buildSpans(widget.text, forceActive: true)),
      );
    }

    if (widget.sentences != null && widget.currentIndex != null) {
      final List<TextSpan> allSpans = [];
      for (int i = 0; i < widget.sentences!.length; i++) {
        final sentence = widget.sentences![i];
        if (i < widget.currentIndex!) {
          // Previous sentences are fully highlighted
          allSpans.addAll(_buildSpans(sentence, forceActive: true));
        } else if (i == widget.currentIndex!) {
          // Current sentence is animated
          allSpans.addAll(_buildSpans(sentence, progress: _progress));
        } else {
          // Future sentences are dimmed
          allSpans.addAll(_buildSpans(sentence, forceInactive: true));
        }
        // Add space between sentences if needed (split removed spacing)
        allSpans.add(const TextSpan(text: ' '));
      }
      return RichText(text: TextSpan(children: allSpans));
    }

    // Legacy mode (Full text)
    return RichText(
      text: TextSpan(children: _buildSpans(widget.text, progress: _progress)),
    );
  }

  List<TextSpan> _buildSpans(
    String text, {
    double progress = 1.0,
    bool forceActive = false,
    bool forceInactive = false,
  }) {
    final List<TextSpan> spans = [];
    final matches = RegExp(r'(\S+|\s+)').allMatches(text);

    int totalNonGaps = 0;
    for (final m in matches) {
      if (m.group(0)?.trim().isNotEmpty == true) totalNonGaps++;
    }

    int activeWordIndex = forceActive
        ? totalNonGaps
        : (totalNonGaps * progress).floor();

    if (forceInactive) activeWordIndex = -1;

    int currentWordCount = 0;

    // Styles
    const baseColor = Colors.white;
    const dimColor = Color(0x66FFFFFF);
    const headerColor = Color(0xFF00FF88);
    const boldColor = Color(0xFFFFD740);

    for (final m in matches) {
      String token = m.group(0)!;
      bool isWhitespace = token.trim().isEmpty;

      if (!isWhitespace) {
        // Apply simple markdown styling
        String displayText = token;
        Color active = baseColor;
        Color inactive = dimColor;
        FontWeight weight = FontWeight.normal;
        double size = 15;

        // Header style
        if (displayText.contains('#')) {
          active = headerColor;
          inactive = headerColor.withOpacity(0.5);
          weight = FontWeight.bold;
          size = 18;
          displayText = displayText.replaceAll('#', '');
          if (displayText.isEmpty) continue;
        }

        // Bold style
        if (displayText.contains('**')) {
          active = boldColor;
          inactive = boldColor.withOpacity(0.5);
          weight = FontWeight.bold;
          displayText = displayText.replaceAll('**', '');
        }

        bool isActive = currentWordCount <= activeWordIndex;

        spans.add(
          TextSpan(
            text: displayText,
            style: TextStyle(
              color: isActive ? active : inactive,
              fontWeight: weight,
              fontSize: size,
              height: 1.6,
              fontFamily: 'Roboto',
            ),
          ),
        );

        currentWordCount++;
      } else {
        spans.add(
          TextSpan(
            text: token,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
        );
      }
    }
    return spans;
  }
}
