import '../../../debate/data/models/debate.dart'; // Ensure correct import path

class Post {
  final String id;
  final String title;
  final String? description;
  final String authorName;
  final String? authorAvatarUrl;
  final String authorId;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final Debate debate;
  bool isLiked; // Local state for optimistic UI

  Post({
    required this.id,
    required this.title,
    this.description,
    required this.authorName,
    this.authorAvatarUrl,
    required this.authorId,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.debate,
    this.isLiked = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      authorName: json['author']?['username'] ?? 'Unknown',
      authorAvatarUrl: json['author']?['avatarUrl'],
      authorId: json['authorId'],
      createdAt: DateTime.parse(json['createdAt']),
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      debate: Debate.fromJson(json['debate']),
    );
  }
}
