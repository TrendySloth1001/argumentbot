import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/models/debate.dart';
import '../../../../core/services/tts_service.dart';

class DebateTurnItem extends StatefulWidget {
  final DebateTurn turn;
  final bool isModelA;

  const DebateTurnItem({super.key, required this.turn, required this.isModelA});

  @override
  State<DebateTurnItem> createState() => _DebateTurnItemState();
}

class _DebateTurnItemState extends State<DebateTurnItem> {
  final TtsService _ttsService = TtsService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    if (_isLoading) return;

    // If already playing, stop
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Split text into sentences for better sync and buffering
      // Identify sentence boundaries: . ! ? followed by space or end of string
      final sentences = widget.turn.content
          .split(RegExp(r'(?<=[.!?])\s+'))
          .where((s) => s.trim().isNotEmpty)
          .toList();

      if (sentences.isEmpty) {
        sentences.add(widget.turn.content);
      }

      // Get token for headers if needed (not supported directly in URI, may need custom source for headers)
      // Note: TtsService.getStreamUrl returns a URL with token param if needed, or we rely on cookie/public access?
      // Step 4272 viewer of tts_service showed it returns a full URL.
      // Assuming URL is accessible or token is in query param.
      // If token is Header-only, ConcatenatingAudioSource might fail without headers?
      // just_audio supports headers in AudioSource.uri(uri, headers: ...).

      final token = await _ttsService.getToken();
      final headers = token != null ? {'Authorization': 'Bearer $token'} : null;

      final source = ConcatenatingAudioSource(
        children: sentences.map((sentence) {
          final url = _ttsService.getStreamUrl(
            sentence,
            voice: widget.isModelA ? 'en_US-amy-medium' : 'en_US-ryan-high',
          );
          return AudioSource.uri(
            Uri.parse(url),
            headers: headers,
            tag: sentence,
          );
        }).toList(),
      );

      await _audioPlayer.setAudioSource(source);

      setState(() {
        _isLoading = false;
        _isPlaying = true;
      });

      // Update UI on completion
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) {
            setState(() => _isPlaying = false);
          }
        }
      });

      await _audioPlayer.play();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

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
                  const Spacer(),
                  // Speaker Button
                  GestureDetector(
                    onTap: _playAudio,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isPlaying
                            ? const Color(0xFF00FF88).withAlpha(30)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isPlaying
                              ? const Color(0xFF00FF88).withAlpha(80)
                              : Colors.white24,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF00FF88),
                              ),
                            )
                          : Icon(
                              _isPlaying ? Icons.stop : Icons.volume_up,
                              size: 16,
                              color: _isPlaying
                                  ? const Color(0xFF00FF88)
                                  : Colors.grey[400],
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
        child: Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(widget.icon, size: 12, color: widget.color),
                ),
                alignment: PlaceholderAlignment.middle,
              ),
              TextSpan(
                text: widget.text,
                style: TextStyle(
                  color: widget.color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          maxLines: _isExpanded ? null : 1,
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
