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
        username = userData['username'] ?? userData['name'];
        profileImage = userData['imageBase64'] ?? "";
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

      // Add to local list and notify listeners
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

  Future<List<Post>> fetchAllPosts() async {
    if (_auth.currentUser == null) return [];

    try {
      DataSnapshot postsSnapshot = await _db.child("posts").get();
      if (!postsSnapshot.exists) {
        _allPosts = [];
        notifyListeners();
        return [];
      }

      Map rawPosts = postsSnapshot.value as Map;

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
      return [];
    }
  }

  // Method to update profile images in all posts for a specific user
  Future<void> updateUserProfileImageInPosts(String userId, String newImageBase64) async {
    bool hasChanges = false;
    
    for (int i = 0; i < _allPosts.length; i++) {
      if (_allPosts[i].userId == userId) {
        _allPosts[i].userProfileImage = newImageBase64;
        hasChanges = true;
      }
    }
    
    if (hasChanges) {
      notifyListeners();
    }
  }

  // Method to refresh posts data from Firebase
  Future<void> refreshPosts() async {
    await fetchAllPosts();
  }

  Future<List<Post>> fetchMyPosts() async {
    if (_auth.currentUser == null) return [];
    try {
      DataSnapshot snapshot = await _db.child("posts").get();
      List<Post> posts = [];
      if (snapshot.exists) {
        Map data = snapshot.value as Map;
        data.forEach((key, value) {
          if (value['userId'] == _auth.currentUser!.uid) {
            posts.add(
              Post.fromMap(
                Map<String, dynamic>.from(value),
                key,
                currentUserId: _auth.currentUser!.uid,
              ),
            );
          }
        });
      }
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    } catch (e) {
      debugPrint("Error fetching my posts: $e");
      return [];
    }
  }

  // Optimized delete post method with immediate UI update and error handling
  Future<bool> deletePost(String postId) async {
    if (_auth.currentUser == null) return false;
    
    // Find the post to delete
    final postToDelete = _allPosts.firstWhere(
      (post) => post.postId == postId,
      orElse: () => throw Exception("Post not found"),
    );
    
    // Check if user owns the post
    if (postToDelete.userId != _auth.currentUser!.uid) {
      debugPrint("User doesn't own this post");
      return false;
    }

    // Store the original index for potential rollback
    final originalIndex = _allPosts.indexOf(postToDelete);
    
    try {
      // Optimistically remove from local list first for immediate UI feedback
      _allPosts.removeWhere((post) => post.postId == postId);
      notifyListeners(); // This triggers immediate UI update
      
      // Delete from Firebase in the background
      await _db.child("posts").child(postId).remove();
      
      // Decrement postsCount
      final userRef = _db.child("users").child(_auth.currentUser!.uid);
      DataSnapshot userSnap = await userRef.get();
      if (userSnap.exists) {
        final userData = Map<String, dynamic>.from(userSnap.value as Map);
        int postsCount = (userData['postsCount'] ?? 1) as int;
        await userRef.update({
          "postsCount": (postsCount > 0 ? postsCount - 1 : 0)
        });
      }
      
      return true;
    } catch (e) {
      debugPrint("Error deleting post: $e");
      
      // Rollback: Re-insert the post at its original position
      if (originalIndex >= 0 && originalIndex <= _allPosts.length) {
        _allPosts.insert(originalIndex, postToDelete);
      } else {
        _allPosts.add(postToDelete); // Fallback to end of list
      }
      
      notifyListeners(); // Update UI to show the post is back
      return false;
    }
  }

  // Optimized toggle like method that only updates the specific post
  Future<void> toggleLike(Post post) async {
    if (_auth.currentUser == null) return;

    try {
      String uid = _auth.currentUser!.uid;
      List<String> updatedLikes = List<String>.from(post.likes);

      // Optimistically update the UI first
      if (post.isLiked) {
        updatedLikes.remove(uid);
        post.isLiked = false;
      } else {
        updatedLikes.add(uid);
        post.isLiked = true;
      }
      post.likes = updatedLikes;

      // Find and update the post in the local list
      int postIndex = _allPosts.indexWhere((p) => p.postId == post.postId);
      if (postIndex != -1) {
        _allPosts[postIndex] = post;
      }

      // Notify listeners to update UI
      notifyListeners();

      // Update Firebase in the background
      await _db
          .child("posts")
          .child(post.postId)
          .update({"likes": updatedLikes});

    } catch (e) {
      debugPrint("Error toggling like: $e");
      
      // Revert the optimistic update if Firebase update fails
      if (post.isLiked) {
        post.likes.remove(_auth.currentUser!.uid);
        post.isLiked = false;
      } else {
        post.likes.add(_auth.currentUser!.uid);
        post.isLiked = true;
      }
      
      // Find and revert the post in the local list
      int postIndex = _allPosts.indexWhere((p) => p.postId == post.postId);
      if (postIndex != -1) {
        _allPosts[postIndex] = post;
      }
      
      notifyListeners();
    }
  }

  // Method to get a specific post by ID (useful for granular updates)
  Post? getPostById(String postId) {
    try {
      return _allPosts.firstWhere((post) => post.postId == postId);
    } catch (e) {
      return null;
    }
  }

  // Method to update a specific post in the list
  void updatePost(Post updatedPost) {
    int postIndex = _allPosts.indexWhere((p) => p.postId == updatedPost.postId);
    if (postIndex != -1) {
      _allPosts[postIndex] = updatedPost;
      notifyListeners();
    }
  }

  // Method to check if a post exists in the local list
  bool hasPost(String postId) {
    return _allPosts.any((post) => post.postId == postId);
  }

  // Method to get posts count
  int get postsCount => _allPosts.length;

  // Method to clear all posts (useful for logout)
  void clearPosts() {
    _allPosts.clear();
    notifyListeners();
  }
}

