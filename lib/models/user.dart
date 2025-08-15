// lib/models/user.dart
class AppUser {
  final String uid;
  final String name;
  final String email;
  final String? imageBase64; // profile image stored in Base64 format
  final int followers;
  final int following;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.imageBase64,
    required this.followers,
    required this.following,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'imageBase64': imageBase64,
      'followers': followers,
      'following': following,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      imageBase64: map['imageBase64'],
      followers: map['followers'] ?? 0,
      following: map['following'] ?? 0,
    );
  }
}
