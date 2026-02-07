import 'package:flutter/material.dart';
import '../../data/models/post.dart';
import '../../data/services/feed_service.dart';
import '../../../debate/presentation/widgets/debate_turn_item.dart';
import '../../../debate/presentation/widgets/power_bar.dart';
import '../../../debate/presentation/widgets/debate_result_view.dart';
import '../../../debate/presentation/screens/debate_setup_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _feedService = FeedService();
  int _commentCount = 0;

  static const Color neonGreen = Color(0xFF00FF88);

  @override
  void initState() {
    super.initState();
    _commentCount = widget.post.commentCount;
  }

  Map<String, double> _calculateScores() {
    double scoreA = 50, scoreB = 50;
    for (var turn in widget.post.debate.turns) {
      final analysis = turn.analysis;
      if (analysis != null) {
        final p = (analysis['persuasiveness'] ?? 50) as num;
        if (turn.speaker == 'MODEL_A') {
          scoreA += p.toDouble();
        } else {
          scoreB += p.toDouble();
        }
      }
    }
    return {'scoreA': scoreA, 'scoreB': scoreB};
  }

  void _showCommentsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CommentsBottomSheet(
        postId: widget.post.id,
        onCommentCountChanged: (count) {
          setState(() => _commentCount = count);
        },
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 16),
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

  @override
  Widget build(BuildContext context) {
    final scores = _calculateScores();
    final isFinished = widget.post.debate.status == 'FINISHED';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Author Info
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: neonGreen.withAlpha(100),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child:
                          widget.post.authorAvatarUrl != null &&
                              widget.post.authorAvatarUrl!.isNotEmpty
                          ? Image.network(
                              widget.post.authorAvatarUrl!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey[900],
                              child: Center(
                                child: Text(
                                  widget.post.authorName.isNotEmpty
                                      ? widget.post.authorName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: neonGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.authorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.post.description != null)
                          Text(
                            widget.post.description!,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // Comment Button
                  GestureDetector(
                    onTap: _showCommentsSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.grey[400],
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_commentCount',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Topic Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[900]!.withAlpha(100),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: neonGreen.withAlpha(50)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isFinished
                                      ? Colors.grey[800]
                                      : neonGreen.withAlpha(30),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isFinished ? 'FINISHED' : 'ACTIVE',
                                  style: TextStyle(
                                    color: isFinished
                                        ? Colors.grey[500]
                                        : neonGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.post.debate.topic,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Power Bar
                          Row(
                            children: [
                              Text(
                                'PRO',
                                style: TextStyle(
                                  color: neonGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: PowerBar(
                                  scoreA: scores['scoreA']!,
                                  scoreB: scores['scoreB']!,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'CON',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons Row
                    Row(
                      children: [
                        // View Result Button (if finished)
                        if (isFinished)
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  isScrollControlled: true,
                                  builder: (context) => DebateResultView(
                                    debate: widget.post.debate,
                                    onClose: () => Navigator.pop(context),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withAlpha(20),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.amber.withAlpha(50),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.emoji_events,
                                      color: Colors.amber,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Result',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (isFinished) const SizedBox(width: 12),
                        // Fork Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DebateSetupScreen(
                                    initialTopic: widget.post.debate.topic,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: neonGreen.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: neonGreen.withAlpha(50),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.sports_mma,
                                    color: neonGreen,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Debate This',
                                    style: TextStyle(
                                      color: neonGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    _buildDivider(),

                    // Transcript Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: neonGreen.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.forum, color: neonGreen, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'TRANSCRIPT',
                                style: TextStyle(
                                  color: neonGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.post.debate.turns.length} turns',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Debate Turns
                    ...widget.post.debate.turns.map((turn) {
                      final isModelA = turn.speaker == 'MODEL_A';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DebateTurnItem(turn: turn, isModelA: isModelA),
                      );
                    }),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Comments Bottom Sheet Widget (Refactored to StatefulWidget)
class _CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final Function(int) onCommentCountChanged;

  const _CommentsBottomSheet({
    required this.postId,
    required this.onCommentCountChanged,
  });

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final _feedService = FeedService();
  final _commentController = TextEditingController();
  List<dynamic> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;

  static const Color neonGreen = Color(0xFF00FF88);

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _feedService.getComments(widget.postId);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
        widget.onCommentCountChanged(comments.length);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await _feedService.addComment(widget.postId, content);
      _commentController.clear();
      // Hide keyboard
      FocusManager.instance.primaryFocus?.unfocus();
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keyboard visibility padding
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A), // Darker background
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: neonGreen.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.chat_bubble, color: neonGreen, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_comments.length} sentiments',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close, color: Colors.grey[400], size: 20),
                  ),
                ),
              ],
            ),
          ),

          Container(height: 1, color: Colors.grey[900]),

          // Comments List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: neonGreen,
                      strokeWidth: 2,
                    ),
                  )
                : _comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.grey[800],
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No sentiments yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildCommentTile(_comments[index]),
                  ),
          ),

          // Input Area (with keyboard padding)
          Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(top: BorderSide(color: Colors.grey[850]!)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        enabled: !_isSending,
                        decoration: InputDecoration(
                          hintText: 'Share your perspective...',
                          hintStyle: TextStyle(color: Colors.grey[700]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _isSending ? null : _sendComment,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isSending ? Colors.grey[800] : neonGreen,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.black,
                              size: 18,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(dynamic comment) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[850]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: neonGreen.withAlpha(80), width: 1.5),
            ),
            child: ClipOval(
              child:
                  comment['author']['avatarUrl'] != null &&
                      comment['author']['avatarUrl'].isNotEmpty
                  ? Image.network(
                      comment['author']['avatarUrl'],
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.black,
                      child: Center(
                        child: Text(
                          (comment['author']['username'] ?? 'U')[0]
                              .toUpperCase(),
                          style: TextStyle(
                            color: neonGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment['author']['username'] ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment['content'],
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
