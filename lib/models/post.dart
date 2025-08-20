// lib/models/post.dart
class Post {
  final String postId;
  final String userId;
  final String content;
  final String? imageUrl; // Base64 string for post image
  final DateTime createdAt;
  List<String> likes;
  bool isLiked; // computed based on current user

  // Extra profile info for display
  final String? username;
  String? userProfileImage; // Base64 string for profile image

  Post({
    required this.postId,
    required this.userId,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.likes = const [],
    this.isLiked = false,
    this.username,
    this.userProfileImage,
  });

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'content': content,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'likes': likes,
      // username & userProfileImage are not stored in posts node directly
    };
  }

  factory Post.fromMap(
    Map<String, dynamic> map,
    String id, {
    String? currentUserId,
    String? username,
    String? userProfileImage,
  }) {
    final likesList = List<String>.from(map['likes'] ?? []);
    return Post(
      postId: id,
      userId: map['userId'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      likes: likesList,
      isLiked: currentUserId != null ? likesList.contains(currentUserId) : false,
      username: username,
      userProfileImage: userProfileImage,
    );
  }
}
