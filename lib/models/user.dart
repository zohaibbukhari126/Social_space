// This class represents a user in the social media app
class AppUser {
  String uid;
  String name;
  String email;
  String username;
  String? imageBase64; // This field is intended to store the user's profile image URL or Base64 string
  int followers;
  int following;
  int postsCount;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.username,
    this.imageBase64,
    required this.followers,
    required this.following,
    required this.postsCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'username': username,
      'imageBase64': imageBase64,
      'followers': followers,
      'following': following,
      'postsCount': postsCount,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      imageBase64: map['imageBase64'],
      followers: map['followers'] ?? 0,
      following: map['following'] ?? 0,
      postsCount: map['postsCount'] ?? 0,
    );
  }
}
