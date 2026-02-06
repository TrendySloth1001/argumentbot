import 'package:flutter/material.dart';
import '../../data/models/post.dart';
import '../../data/services/feed_service.dart';
import '../../../debate/presentation/widgets/debate_turn_item.dart';
import '../../../debate/presentation/widgets/power_bar.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _feedService = FeedService();
  final _commentController = TextEditingController();
  List<dynamic> _comments = [];
  bool _isLoading = true;

  static const Color neonGreen = Color(0xFF00FF88);

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _feedService.getComments(widget.post.id);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      await _feedService.addComment(widget.post.id, _commentController.text);
      _commentController.clear();
      _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, double> _calculateScores() {
    double scoreA = 50;
    double scoreB = 50;

    for (var turn in widget.post.debate.turns) {
      final analysis = turn.analysis;
      if (analysis != null) {
        final persuasiveness = (analysis['persuasiveness'] ?? 50) as num;
        if (turn.speaker == 'MODEL_A') {
          scoreA += persuasiveness.toDouble() * 0.5;
        } else {
          scoreB += persuasiveness.toDouble() * 0.5;
        }
      }
    }

    return {'scoreA': scoreA, 'scoreB': scoreB};
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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Debate Post',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Topic
                  Text(
                    widget.post.debate.topic,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Power Bar with labels
                  Row(
                    children: [
                      Text(
                        'PRO',
                        style: TextStyle(
                          color: neonGreen,
                          fontSize: 11,
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
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  _buildDivider(),

                  // Author
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: neonGreen.withAlpha(100),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: widget.post.authorAvatarUrl != null
                              ? Image.network(
                                  widget.post.authorAvatarUrl!,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.grey[900],
                                  child: Center(
                                    child: Text(
                                      widget.post.authorName[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
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
                              widget.post.authorName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.post.description != null)
                              Text(
                                widget.post.description!,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  _buildDivider(),

                  // Transcript Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
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
                  const SizedBox(height: 16),

                  // Debate Turns
                  ...widget.post.debate.turns.map((turn) {
                    final isModelA = turn.speaker == 'MODEL_A';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DebateTurnItem(turn: turn, isModelA: isModelA),
                    );
                  }),

                  _buildDivider(),

                  // Comments Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.grey[500],
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'COMMENTS (${_comments.length})',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Comments List
                  if (_isLoading)
                    Center(
                      child: CircularProgressIndicator(
                        color: neonGreen,
                        strokeWidth: 2,
                      ),
                    )
                  else if (_comments.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.grey[700],
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No comments yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._comments.map((comment) => _buildCommentTile(comment)),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Input Area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildCommentTile(dynamic comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.grey[800],
            backgroundImage: comment['author']['avatarUrl'] != null
                ? NetworkImage(comment['author']['avatarUrl'])
                : null,
            child: comment['author']['avatarUrl'] == null
                ? const Icon(Icons.person, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment['author']['username'] ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comment['content'],
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.grey[900]!)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendComment,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: neonGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.black, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
