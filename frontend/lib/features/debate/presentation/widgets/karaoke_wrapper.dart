import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class KaraokeWrapper extends StatefulWidget {
  final Widget child;
  final AudioPlayer? audioPlayer;
  final bool isPlaying;
  final Color highlightColor;

  const KaraokeWrapper({
    super.key,
    required this.child,
    this.audioPlayer,
    this.isPlaying = false,
    required this.highlightColor,
  });

  @override
  State<KaraokeWrapper> createState() => _KaraokeWrapperState();
}

class _KaraokeWrapperState extends State<KaraokeWrapper> {
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

    // Listen to duration changes (it might stream in)
    _durationStream = player.durationStream.listen((duration) {
      if (duration != null) {
        setState(() => _totalDuration = duration);
      }
    });

    // Listen to position
    _positionStream = player.positionStream.listen((position) {
      if (_totalDuration.inMilliseconds > 0) {
        if (mounted) {
          setState(() {
            _progress = position.inMilliseconds / _totalDuration.inMilliseconds;
            if (_progress > 1.0) _progress = 1.0;
            if (_progress < 0.0) _progress = 0.0;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(KaraokeWrapper oldWidget) {
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
    if (!widget.isPlaying || widget.audioPlayer == null) {
      return widget.child;
    }

    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.black, // Fully opaque (keeps original color)
            Colors.black.withOpacity(0.3), // Dimmed (fades original color)
          ],
          stops: [
            _progress,
            _progress + 0.1, // Smooth fade
          ],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: widget.child,
    );
  }
}
