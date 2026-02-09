import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/models/debate.dart';
import '../../data/services/debate_service.dart';
import '../../../../core/services/socket_service.dart';
import '../widgets/power_bar.dart';
import '../../../feed/presentation/widgets/share_debate_dialog.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/data/voice_settings.dart';
import '../widgets/audio_waveform.dart';
import '../widgets/karaoke_text.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:record/record.dart';
import 'dart:convert';
import 'dart:async';

class DebateScreen extends StatefulWidget {
  final String debateId;

  const DebateScreen({super.key, required this.debateId});

  @override
  State<DebateScreen> createState() => _DebateScreenState();
}

class _DebateScreenState extends State<DebateScreen> {
  final _debateService = DebateService();
  final _ttsService = TtsService();
  final _socketService = SocketService();

  Debate? _debate;
  bool _isLoading = true;
  bool _isProcessingTurn = false;
  final ScrollController _scrollController = ScrollController();
  final _turnController = TextEditingController();

  // TTS state per turn
  final Map<String, bool> _playingTurns = {};
  final Map<String, bool> _loadingTurns = {};
  final Map<String, AudioPlayer> _audioPlayers = {};
  final Map<String, List<String>> _turnSentences = {};
  final Map<String, int> _turnCurrentIndices = {};

  static const Color neonGreen = Color(0xFF00FF88);
  static const Color neonPurple = Color(0xFF8E2DE2);
  static const Color neonBlue = Color(0xFF00B4DB);

  bool _isKaraokeEnabled = true;

  // STT
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isListening = false;

  // Store subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _loadVoiceSettings();
    _loadDebate();

    _subscriptions.add(
      _socketService.onSttResult.listen((message) {
        print("DebateScreen: STT Message received: $message");
        try {
          final data = jsonDecode(message);
          if (data['text'] != null) {
            setState(() {
              _turnController.text = data['text'];
              _turnController.selection = TextSelection.fromPosition(
                TextPosition(offset: _turnController.text.length),
              );
            });
          }
        } catch (e) {
          print("DebateScreen: Error parsing STT: $e");
        }
      }),
    );
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final stream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );

        if (mounted) setState(() => _isListening = true);

        stream.listen((data) {
          _socketService.sendAudioChunk(data);
        });
      } else {
        print("STT: No microphone permission");
      }
    } catch (e) {
      print("Error starting record: $e");
    }
  }

  Future<void> _stopRecording() async {
    await _audioRecorder.stop();
    if (mounted) setState(() => _isListening = false);
  }

  Future<void> _loadVoiceSettings() async {
    final karaoke = await VoiceSettings.getKaraokeEnabled();
    if (mounted) {
      setState(() => _isKaraokeEnabled = karaoke);
    }
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _turnController.dispose();
    _scrollController.dispose();
    for (final player in _audioPlayers.values) {
      player.dispose();
    }
    _audioRecorder.dispose();
    super.dispose();
  }

  // Strip markdown for natural TTS reading
  String _stripMarkdown(String text) {
    return text
        // Remove headers (# ## ### etc)
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        // Remove bold/italic markers
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')
        .replaceAll(RegExp(r'__([^_]+)__'), r'$1')
        .replaceAll(RegExp(r'_([^_]+)_'), r'$1')
        // Remove inline code
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
        // Remove links but keep text
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        // Remove bullet points
        .replaceAll(RegExp(r'^[\s]*[-*+]\s+', multiLine: true), '')
        // Remove numbered lists
        .replaceAll(RegExp(r'^[\s]*\d+\.\s+', multiLine: true), '')
        // Remove blockquotes
        .replaceAll(RegExp(r'^>\s*', multiLine: true), '')
        // Clean up extra whitespace
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  void _stopAllAudio() {
    for (final player in _audioPlayers.values) {
      player.stop();
    }
    setState(() {
      _playingTurns.updateAll((key, value) => false);
      _loadingTurns.updateAll((key, value) => false);
      _turnCurrentIndices.updateAll((key, value) => 0);
    });
  }

  Future<void> _playTurnAudio(DebateTurn turn, {bool isModelA = true}) async {
    // Initialize player if needed
    if (!_audioPlayers.containsKey(turn.id)) {
      _audioPlayers[turn.id] = AudioPlayer();
    }

    final player = _audioPlayers[turn.id]!;

    // Listen for completion to update UI
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() {
            _playingTurns[turn.id] = false;
            _turnCurrentIndices[turn.id] = 0;
          });
        }
      }
    });

    // Listen for current sentence index
    player.currentIndexStream.listen((index) {
      if (mounted && index != null) {
        setState(() {
          _turnCurrentIndices[turn.id] = index;
        });
      }
    });

    try {
      if (_playingTurns[turn.id] == true) {
        await player.stop();
        setState(() {
          _playingTurns[turn.id] = false;
        });
      } else {
        // Stop other players
        _stopAllAudio();

        setState(() {
          _playingTurns[turn.id] = true;
          _loadingTurns[turn.id] = true;
          _turnCurrentIndices[turn.id] = 0;
        });

        // Strip markdown before TTS
        final cleanContent = _stripMarkdown(turn.content);

        // Split text into sentences
        final sentences = cleanContent
            .split(RegExp(r'(?<=[.!?])\s+'))
            .where((s) => s.trim().isNotEmpty)
            .toList();

        if (sentences.isEmpty) sentences.add(cleanContent);
        _turnSentences[turn.id] = sentences;

        // Get the appropriate voice based on speaker
        final voice = isModelA
            ? await VoiceSettings.getProponentVoice()
            : await VoiceSettings.getOpponentVoice();

        // Get token
        final token = await _ttsService.getToken();
        final headers = token != null
            ? {'Authorization': 'Bearer $token'}
            : null;

        // Create Playlist
        final audioSources = sentences.map((sentence) {
          final url = _ttsService.getStreamUrl(sentence, voice: voice);
          return LockCachingAudioSource(
            Uri.parse(url),
            headers: headers,
            tag: sentence,
          );
        }).toList();

        await player.setAudioSources(audioSources);
        await player.play();

        setState(() {
          _loadingTurns[turn.id] = false;
        });
      }
    } catch (e) {
      setState(() {
        _playingTurns[turn.id] = false;
        _loadingTurns[turn.id] = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadDebate() async {
    try {
      final debate = await _debateService.getDebate(widget.debateId);
      setState(() {
        _debate = debate;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _nextTurn() async {
    if (_isProcessingTurn) return;
    setState(() => _isProcessingTurn = true);

    try {
      String fullContent = '';
      DebateTurn? tempTurn;

      await for (final event in _debateService.streamTurn(widget.debateId)) {
        if (event.containsKey('done')) {
          _loadDebate();
          break;
        }

        if (event.containsKey('content')) {
          final content = event['content'];
          final speaker = event['speaker'];
          fullContent += content;

          setState(() {
            if (tempTurn == null) {
              tempTurn = DebateTurn(
                id: 'temp',
                speaker: speaker,
                content: fullContent,
                timestamp: DateTime.now(),
                modelName: 'llama3.2',
              );
              _debate!.turns.add(tempTurn!);
            } else {
              _debate!.turns.last = DebateTurn(
                id: 'temp',
                speaker: speaker,
                content: fullContent,
                timestamp: DateTime.now(),
                modelName: 'llama3.2',
              );
            }
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingTurn = false);
    }
  }

  Future<void> _submitUserTurn() async {
    if (_turnController.text.trim().isEmpty) return;
    final content = _turnController.text.trim();
    _turnController.clear();

    // Optimistically add turn
    setState(() {
      _debate!.turns.add(
        DebateTurn(
          id: 'user_pending',
          speaker: 'USER',
          content: content,
          timestamp: DateTime.now(),
          modelName: 'You',
        ),
      );
    });
    _scrollToBottom();

    try {
      // Send to backend
      final result = await _debateService.submitUserTurn(
        widget.debateId,
        content,
      );

      if (result.finished) {
        // User conceded - debate is over
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You conceded! Debate ended.'),
              backgroundColor: Colors.orange,
            ),
          );
          // Reload to get final state
          await _loadDebate();
        }
        return;
      }

      // Trigger AI response immediately
      _nextTurn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  bool get _isUserTurn {
    if (_debate?.mode != 'USER_VS_AI') return false;
    if (_debate!.turns.isEmpty) return _debate!.userRole == 'PRO';
    // If last speaker was NOT user, it's user's turn
    return _debate!.turns.last.speaker != 'USER';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: neonGreen)),
      );
    }

    if (_debate == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.grey[700], size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load debate',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate scores
    double scoreA = 50, scoreB = 50;
    for (var turn in _debate!.turns) {
      if (turn.analysis != null) {
        final p = (turn.analysis!['persuasiveness'] ?? 50) as num;
        if (turn.speaker == 'MODEL_A' || turn.speaker == 'USER') {
          scoreA += p.toDouble();
        } else {
          scoreB += p.toDouble();
        }
      }
    }
    // Clamp scores to prevent negative values or extreme overflow
    scoreA = scoreA.clamp(0, double.maxFinite);
    scoreB = scoreB.clamp(0, double.maxFinite);

    if (_debate!.mode == 'USER_VS_AI' && _isUserTurn && !_isProcessingTurn) {
      // Auto-focus logic could go here
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(scoreA, scoreB),
            _buildDivider(),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                itemCount: _debate!.turns.length,
                itemBuilder: (context, index) {
                  final turn = _debate!.turns[index];
                  return _buildMessageBubble(turn, turn.speaker == 'MODEL_A');
                },
              ),
            ),

            // Bottom control
            _buildBottomControl(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double scoreA, double scoreB) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _debate!.topic,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => ShareDebateDialog.show(context, widget.debateId),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: neonGreen.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.share, color: neonGreen, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Score bar
          Row(
            children: [
              const Text(
                'PRO',
                style: TextStyle(
                  color: neonPurple,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PowerBar(scoreA: scoreA, scoreB: scoreB),
              ),
              const SizedBox(width: 8),
              const Text(
                'CON',
                style: TextStyle(
                  color: neonBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.grey[800]!,
            Colors.grey[800]!,
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(DebateTurn turn, bool isModelA) {
    if (turn.speaker == 'USER') {
      return _buildUserMessageBubble(turn);
    }
    final color = isModelA ? neonPurple : neonBlue;
    final label = isModelA ? 'PROPONENT' : 'OPPONENT';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speaker label
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  turn.modelName ?? 'Llama 3.2',
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
              ),
              const SizedBox(width: 8),
              // Speaker Button
              GestureDetector(
                onTap: () => _playTurnAudio(turn, isModelA: isModelA),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _playingTurns[turn.id] == true
                        ? neonGreen.withAlpha(30)
                        : Colors.grey[900],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _playingTurns[turn.id] == true
                          ? neonGreen.withAlpha(80)
                          : Colors.grey[700]!,
                    ),
                  ),
                  child: _loadingTurns[turn.id] == true
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: neonGreen,
                          ),
                        )
                      : Icon(
                          _playingTurns[turn.id] == true
                              ? Icons.stop
                              : Icons.volume_up,
                          size: 14,
                          color: _playingTurns[turn.id] == true
                              ? neonGreen
                              : Colors.grey[400],
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          if (_playingTurns[turn.id] == true)
            StreamBuilder<PlayerState>(
              stream: _audioPlayers[turn.id]?.playerStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final isBuffering =
                    state?.processingState == ProcessingState.buffering ||
                    state?.processingState == ProcessingState.loading;
                final isReady =
                    state?.processingState == ProcessingState.ready ||
                    state?.processingState == ProcessingState.completed;
                final isActuallyPlaying = (state?.playing ?? false) && isReady;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _isKaraokeEnabled
                        ? KaraokeText(
                            text: turn.content,
                            audioPlayer: _audioPlayers[turn.id],
                            isPlaying: isActuallyPlaying,
                            sentences: _turnSentences[turn.id],
                            currentIndex: _turnCurrentIndices[turn.id],
                          )
                        : Text(
                            turn.content,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.6,
                            ),
                          ),
                    const SizedBox(height: 12),
                    // Sound Bar or Loading Indicator
                    if (isBuffering)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: LinearProgressIndicator(
                          color: neonGreen.withOpacity(0.5),
                          backgroundColor: Colors.grey[800],
                          minHeight: 2,
                        ),
                      )
                    else
                      StreamBuilder<Duration>(
                        stream: _audioPlayers[turn.id]?.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration =
                              _audioPlayers[turn.id]?.duration ?? Duration.zero;

                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: AudioWaveform(
                              isPlaying: isActuallyPlaying,
                              position: position,
                              duration: duration,
                              color: neonGreen,
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            )
          else
            MarkdownBody(
              data: turn.content,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.6,
                ),
                h2: const TextStyle(
                  color: neonGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 2,
                ),
                h3: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 2,
                ),
                listBullet: const TextStyle(color: Colors.white),
              ),
            ),

          // Analysis tags
          if (turn.analysis != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (turn.analysis!['key_point'] != null)
                  _buildTag(
                    Icons.lightbulb_outline,
                    turn.analysis!['key_point'],
                    Colors.amber,
                  ),
                if ((turn.analysis!['persuasiveness'] ?? 0) > 80)
                  _buildTag(
                    Icons.local_fire_department,
                    'Strong Point',
                    Colors.redAccent,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserMessageBubble(DebateTurn turn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: neonGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: neonGreen.withOpacity(0.5)),
            ),
            child: const Text(
              'YOU',
              style: TextStyle(
                color: neonGreen,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Text(
              turn.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
          if (turn.analysis != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (turn.analysis!['persuasiveness'] != null)
                  _buildTag(
                    Icons.auto_graph,
                    'Score: ${turn.analysis!['persuasiveness']}',
                    neonGreen,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String text, Color color) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Key Point',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            content: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: neonGreen)),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(77)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControl() {
    if (_debate!.status == 'FINISHED') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          border: Border(top: BorderSide(color: Colors.grey[800]!)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: neonGreen, size: 24),
            const SizedBox(width: 12),
            const Text(
              'Debate Concluded',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _showResultsBottomSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: neonGreen.withOpacity(0.2),
                foregroundColor: neonGreen,
                elevation: 0,
                side: const BorderSide(color: neonGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('View Results'),
            ),
          ],
        ),
      );
    }

    if (_debate!.mode == 'USER_VS_AI') {
      if (_isUserTurn) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border(top: BorderSide(color: Colors.grey[900]!)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _turnController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Your argument...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Mic Button
              AvatarGlow(
                animate: _isListening,
                glowColor: neonGreen,
                glowRadiusFactor: 0.4,
                duration: const Duration(milliseconds: 2000),
                repeat: true,
                child: IconButton(
                  onPressed: _isListening ? _stopRecording : _startRecording,
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? neonGreen : Colors.grey[400],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _submitUserTurn,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: neonGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.black, size: 20),
                ),
              ),
            ],
          ),
        );
      } else {
        // AI is thinking or speaking
        if (_isProcessingTurn) {
          return Container(
            padding: const EdgeInsets.all(24),
            color: Colors.black,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: neonGreen,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Opponent is thinking...',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }
        // Fallback if not processing but not user turn? Should not happen often unless specific state.
        // Maybe "Waiting..."
        return Container();
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.grey[900]!)),
      ),
      child: GestureDetector(
        onTap: _isProcessingTurn ? null : _nextTurn,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _isProcessingTurn ? Colors.grey[800] : neonGreen,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isProcessingTurn
                ? null
                : [
                    BoxShadow(
                      color: neonGreen.withAlpha(77),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: _isProcessingTurn
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt, color: Colors.black, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Trigger Counter-Argument',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _showResultsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.grey[800]!)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.emoji_events, color: Colors.amber, size: 48),
            const SizedBox(height: 16),
            const Text(
              'DEBATE RESULT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildScoreColumn(
                  'PRO',
                  _debate!.turns
                          .where((t) => t.speaker == 'MODEL_A')
                          .fold(
                            0.0,
                            (sum, t) =>
                                sum + (t.analysis?['persuasiveness'] ?? 50),
                          ) /
                      (_debate!.turns
                                  .where((t) => t.speaker == 'MODEL_A')
                                  .length ==
                              0
                          ? 1
                          : _debate!.turns
                                .where((t) => t.speaker == 'MODEL_A')
                                .length),
                  neonPurple,
                ),
                Container(width: 1, height: 40, color: Colors.grey[800]),
                _buildScoreColumn(
                  'CON',
                  _debate!.turns
                          .where((t) => t.speaker != 'MODEL_A')
                          .fold(
                            0.0,
                            (sum, t) =>
                                sum + (t.analysis?['persuasiveness'] ?? 50),
                          ) /
                      (_debate!.turns
                                  .where((t) => t.speaker != 'MODEL_A')
                                  .length ==
                              0
                          ? 1
                          : _debate!.turns
                                .where((t) => t.speaker != 'MODEL_A')
                                .length),
                  neonBlue,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_debate!.turns.isNotEmpty &&
                _debate!.turns.last.analysis?['conceded'] == true)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flag, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_debate!.turns.last.speaker == 'USER' ? 'YOU' : _debate!.turns.last.modelName} CONCEDED',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close sheet
                  Navigator.pop(context); // Back to menu
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: neonGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Exit Debate',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreColumn(String label, double score, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          score.toStringAsFixed(1),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'AVG SCORE',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
