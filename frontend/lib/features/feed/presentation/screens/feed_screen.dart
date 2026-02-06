import 'package:flutter/material.dart';
import '../../data/services/feed_service.dart';
import '../../data/models/post.dart';
import 'post_detail_screen.dart';

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
    setState(() {
      _posts[index].isLiked = !wasLiked;
    });

    try {
      await _feedService.toggleLike(post.id);
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _posts[index].isLiked = wasLiked;
        });
      }
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
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Feed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: _refresh,
                    child: Icon(Icons.refresh, color: Colors.grey[600]),
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
                          return _buildPostItem(_posts[index], index);
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
          Icon(Icons.chat_bubble_outline, color: Colors.grey[700], size: 48),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share a debate!',
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPostItem(Post post, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row - tappable to open post
          GestureDetector(
            onTap: () => _openPost(post),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: neonGreen, width: 1.5),
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
                        post.authorName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatTime(post.createdAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Content - tappable to open post
          GestureDetector(
            onTap: () => _openPost(post),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.description != null && post.description!.isNotEmpty)
                  Text(
                    post.description!,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: neonGreen.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: neonGreen.withAlpha(77)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.forum_outlined,
                        color: neonGreen,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          post.debate.topic,
                          style: const TextStyle(
                            color: neonGreen,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Stats row - like button is tappable separately
          Row(
            children: [
              // Like button
              GestureDetector(
                onTap: () => _toggleLike(post, index),
                child: Row(
                  children: [
                    Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: post.isLiked ? Colors.redAccent : Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.likeCount + (post.isLiked ? 1 : 0)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Comments - opens post
              GestureDetector(
                onTap: () => _openPost(post),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.commentCount}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
