// lib/models/post.dart
class Post {
  final String postId;
  final String userId;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;

  Post({
    required this.postId,
    required this.userId,
    required this.content,
    this.imageUrl,
    required this.createdAt,
  });

  factory Post.fromMap(Map<String, dynamic> map, String postId) {
    return Post(
      postId: postId,
      userId: map['userId'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'content': content,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
