
// This class represents a social media post
class Post {
  final String postId;
  final String userId;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  List<String> likes;
  bool isLiked;

  final String? username; // This field is intended to store the user's display name
  String? userProfileImage; // This field is intended to store the user's profile image URL or Base64 string

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
      isLiked: currentUserId != null
          ? likesList.contains(currentUserId)
          : false,
      username: username,
      userProfileImage: userProfileImage,
    );
  }
}
