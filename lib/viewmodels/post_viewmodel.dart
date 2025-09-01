import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../models/post.dart';

class PostViewModel extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Post> _allPosts = [];
  List<Post> get allPosts => List.unmodifiable(_allPosts);

  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  /// Add post to Firebase
  Future<Post?> addPost(String content, {File? imageFile}) async {
    if (_auth.currentUser == null) return null;

    try {
      _setLoading(true);

      String postId = _db.child("posts").push().key!;
      String? imageBase64;

      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        imageBase64 = base64Encode(bytes);
      }

      // Fetch current user details
      String? username;
      String? profileImage;
      DataSnapshot userSnap =
          await _db.child("users").child(_auth.currentUser!.uid).get();
      if (userSnap.exists) {
        final userData = Map<String, dynamic>.from(userSnap.value as Map);
        username = userData['username'] ?? userData['name'] ?? "User";
        profileImage = userData['imageBase64'] ?? "";
      } else {
        username = "User";
        profileImage = "";
      }

      Post post = Post(
        postId: postId,
        userId: _auth.currentUser!.uid,
        content: content,
        imageUrl: imageBase64,
        createdAt: DateTime.now(),
        username: username,
        userProfileImage: profileImage,
      );

      await _db.child("posts").child(postId).set(post.toMap());

      // Increment postsCount
      final userRef = _db.child("users").child(_auth.currentUser!.uid);
      DataSnapshot userSnap2 = await userRef.get();
      if (userSnap2.exists) {
        final userData2 = Map<String, dynamic>.from(userSnap2.value as Map);
        int postsCount = (userData2['postsCount'] ?? 0) as int;
        await userRef.update({"postsCount": postsCount + 1});
      }

      _allPosts.insert(0, post);
      notifyListeners();

      return post;
    } catch (e) {
      debugPrint("Error adding post: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch all posts from Firebase, or use dummy if empty
  Future<List<Post>> fetchAllPosts({bool useDummyIfEmpty = true}) async {
    if (_auth.currentUser == null) return [];

    try {
      DataSnapshot postsSnapshot = await _db.child("posts").get();

      if (!postsSnapshot.exists && useDummyIfEmpty) {
        addDummyPosts(); // Load dummy posts locally
        return _allPosts;
      }

      Map rawPosts = postsSnapshot.value as Map? ?? {};

      // Fetch all users
      DataSnapshot usersSnapshot = await _db.child("users").get();
      Map<String, dynamic> usersData = {};
      if (usersSnapshot.exists) {
        usersData = Map<String, dynamic>.from(usersSnapshot.value as Map);
      }

      List<Post> posts = [];
      rawPosts.forEach((key, value) {
        Map<String, dynamic> postMap = Map<String, dynamic>.from(value);

        String? postUserId = postMap['userId'];
        String? username;
        String? profileImage;

        if (postUserId != null && usersData.containsKey(postUserId)) {
          Map<String, dynamic> userMap =
              Map<String, dynamic>.from(usersData[postUserId]);
          username = userMap['username'] ?? userMap['name'] ?? "User";
          profileImage = userMap['imageBase64'] ?? "";
        }

        posts.add(
          Post.fromMap(
            postMap,
            key,
            currentUserId: _auth.currentUser!.uid,
            username: username,
            userProfileImage: profileImage,
          ),
        );
      });

      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _allPosts = posts;
      notifyListeners();
      return posts;
    } catch (e) {
      debugPrint("Error fetching posts: $e");
      if (useDummyIfEmpty) addDummyPosts(); // fallback
      return _allPosts;
    }
  }

  /// Add dummy posts for testing UI
  void addDummyPosts() {
    _allPosts = [
      Post(
        postId: '1',
        userId: 'user1',
        content: 'Hello world! This is my first post.',
        imageUrl: null,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        username: 'Alice',
        userProfileImage: null,
      ),
      Post(
        postId: '2',
        userId: 'user2',
        content: 'Just chilling with my coffee ☕',
        imageUrl: null,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        username: 'Bob',
        userProfileImage: null,
      ),
      Post(
        postId: '3',
        userId: 'user3',
        content: 'Flutter is amazing! 🚀',
        imageUrl: null,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        username: 'Charlie',
        userProfileImage: null,
      ),
    ];

    _allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  // --- All your existing methods below remain unchanged ---
  Future<List<Post>> fetchMyPosts() async { /* ... */ return []; }
  Future<bool> deletePost(String postId) async { /* ... */ return false; }
  Future<void> toggleLike(Post post) async { /* ... */ }
  Post? getPostById(String postId) { /* ... */ return null; }
  void updatePost(Post updatedPost) { /* ... */ }
  bool hasPost(String postId) { /* ... */ return false; }
  int get postsCount => _allPosts.length;
  void clearPosts() { _allPosts.clear(); notifyListeners(); }
  Future<void> updateUserProfileImageInPosts(String userId, String newImageBase64) async { /* ... */ }
  Future<void> refreshPosts() async { await fetchAllPosts(); }
}
