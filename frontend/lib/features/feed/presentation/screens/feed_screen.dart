import 'package:flutter/material.dart';
import '../../data/services/feed_service.dart';
import '../../data/models/post.dart';
import 'post_detail_screen.dart';
import '../../../debate/presentation/widgets/power_bar.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _feedService = FeedService();
  final List<Post> _posts = [];
  bool _isLoading = true;
  String? _cursor;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  static const Color neonGreen = Color(0xFF00FF88);

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        _hasMore) {
      _loadFeed();
    }
  }

  Future<void> _loadFeed() async {
    if (!_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final newPosts = await _feedService.getFeed(cursor: _cursor);
      setState(() {
        if (newPosts.isEmpty) {
          _hasMore = false;
        } else {
          _posts.addAll(newPosts);
          _cursor = newPosts.last.id;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load feed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    _cursor = null;
    _hasMore = true;
    _posts.clear();
    await _loadFeed();
  }

  Future<void> _toggleLike(Post post, int index) async {
    final wasLiked = post.isLiked;
    setState(() => _posts[index].isLiked = !wasLiked);

    try {
      await _feedService.toggleLike(post.id);
    } catch (e) {
      if (mounted) setState(() => _posts[index].isLiked = wasLiked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: neonGreen.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.public, color: neonGreen, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Feed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _refresh,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.refresh,
                        color: Colors.grey[500],
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildDivider(),

            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: neonGreen,
                child: _posts.isEmpty && !_isLoading
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        itemCount: _posts.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _posts.length) {
                            return _isLoading
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(
                                        color: neonGreen,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : const SizedBox(height: 50);
                          }
                          return _buildPostCard(_posts[index], index);
                        },
                      ),
              ),
            ),
          ],
        ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.forum_outlined,
              color: Colors.grey[700],
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No posts yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share a debate!',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Post post, int index) {
    final isFinished = post.debate.status == 'FINISHED';

    // Calculate scores for mini bar
    double scoreA = 50, scoreB = 50;
    for (var turn in post.debate.turns) {
      if (turn.analysis != null) {
        final p = (turn.analysis!['persuasiveness'] ?? 50) as num;
        if (turn.speaker == 'MODEL_A') {
          scoreA += p.toDouble();
        } else {
          scoreB += p.toDouble();
        }
      }
    }

    return GestureDetector(
      onTap: () => _openPost(post),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withAlpha(150),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[850]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
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
                      child:
                          post.authorAvatarUrl != null &&
                              post.authorAvatarUrl!.isNotEmpty
                          ? Image.network(
                              post.authorAvatarUrl!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.black,
                              alignment: Alignment.center,
                              child: Text(
                                post.authorName.isNotEmpty
                                    ? post.authorName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: neonGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Author Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTime(post.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status Badge
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
                        color: isFinished ? Colors.grey[500] : neonGreen,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Description
            if (post.description != null && post.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  post.description!,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Topic Card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: neonGreen.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: neonGreen.withAlpha(40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.forum_outlined, color: neonGreen, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            post.debate.topic,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Mini Power Bar
                    MiniPowerBar(scoreA: scoreA, scoreB: scoreB),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[850]!)),
              ),
              child: Row(
                children: [
                  // Like Button
                  GestureDetector(
                    onTap: () => _toggleLike(post, index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: post.isLiked
                            ? Colors.redAccent.withAlpha(20)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            post.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: post.isLiked
                                ? Colors.redAccent
                                : Colors.grey[600],
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${post.likeCount + (post.isLiked ? 1 : 0)}',
                            style: TextStyle(
                              color: post.isLiked
                                  ? Colors.redAccent
                                  : Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Comments
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.grey[600],
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.commentCount}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // View Arrow
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey[700],
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPost(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
