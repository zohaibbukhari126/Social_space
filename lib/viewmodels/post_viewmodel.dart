// lib/viewmodels/post_viewmodel.dart
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../models/post.dart';

class PostViewModel extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();

  Future<Post?> addPost(String content, {File? imageFile}) async {
    if (_auth.currentUser == null) return null;

    String postId = _db.child("posts").push().key!;
    String? imageBase64;

    if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      imageBase64 = base64Encode(bytes);
    }

    // Fetch current user details to include username and profile image
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
    // Increment postsCount for user
    final userRef = _db.child("users").child(_auth.currentUser!.uid);
    DataSnapshot userSnap2 = await userRef.get();
    if (userSnap2.exists) {
      final userData2 = Map<String, dynamic>.from(userSnap2.value as Map);
      int postsCount = (userData2['postsCount'] ?? 0) as int;
      await userRef.update({"postsCount": postsCount + 1});
    }
    notifyListeners();
    return post;
  }

  Future<List<Post>> fetchAllPosts() async {
    if (_auth.currentUser == null) return [];

    // Fetch all posts
    DataSnapshot postsSnapshot = await _db.child("posts").get();
    if (!postsSnapshot.exists) return [];

    Map rawPosts = postsSnapshot.value as Map;

    // Fetch all users so we can map IDs to names/images
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
    return posts;
  }

  Future<List<Post>> fetchMyPosts() async {
    if (_auth.currentUser == null) return [];
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
  }

  Future<void> deletePost(String postId) async {
    if (_auth.currentUser == null) return;
    DataSnapshot snapshot = await _db.child("posts").child(postId).get();
    if (snapshot.exists) {
      Map value = snapshot.value as Map;
      if (value['userId'] == _auth.currentUser!.uid) {
        await _db.child("posts").child(postId).remove();
        // Decrement postsCount for user
        final userRef = _db.child("users").child(_auth.currentUser!.uid);
        DataSnapshot userSnap2 = await userRef.get();
        if (userSnap2.exists) {
          final userData2 = Map<String, dynamic>.from(userSnap2.value as Map);
          int postsCount = (userData2['postsCount'] ?? 1) as int;
          await userRef.update({"postsCount": (postsCount > 0 ? postsCount - 1 : 0)});
        }
      }
    }
    notifyListeners();
  }

  Future<void> toggleLike(Post post) async {
    if (_auth.currentUser == null) return;

    String uid = _auth.currentUser!.uid;
    List<String> updatedLikes = List<String>.from(
      post.likes,
    ); // clone so it's mutable

    if (post.isLiked) {
      updatedLikes.remove(uid);
    } else {
      updatedLikes.add(uid);
    }

    await _db.child("posts").child(post.postId).update({"likes": updatedLikes});

    // Instead of clearing the original unmodifiable list, replace it with a mutable copy
    post.likes = updatedLikes; // <-- make 'likes' non-final in Post model
    post.isLiked = !post.isLiked;

    notifyListeners();
  }
}
