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

  // Add new post with optional image (stored as Base64 in RTDB)
Future<Post?> addPost(String content, {File? imageFile}) async {
  if (_auth.currentUser == null) return null;

  String postId = _db.child("posts").push().key!;
  String? imageBase64;

  if (imageFile != null) {
    final bytes = await imageFile.readAsBytes();
    imageBase64 = base64Encode(bytes);
  }

  Post post = Post(
    postId: postId,
    userId: _auth.currentUser!.uid,
    content: content,
    imageUrl: imageBase64,
    createdAt: DateTime.now(),
  );

  await _db.child("posts").child(postId).set(post.toMap());
  notifyListeners();
  return post; // return the new post so UI can update instantly
}


  // Fetch all posts for main feed
  Future<List<Post>> fetchAllPosts() async {
    DataSnapshot snapshot = await _db.child("posts").get();
    List<Post> posts = [];
    if (snapshot.exists) {
      Map data = snapshot.value as Map;
      data.forEach((key, value) {
        posts.add(Post.fromMap(Map<String, dynamic>.from(value), key));
      });
    }
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  // Fetch only current user's posts
  Future<List<Post>> fetchMyPosts() async {
    if (_auth.currentUser == null) return [];
    DataSnapshot snapshot = await _db.child("posts").get();
    List<Post> posts = [];
    if (snapshot.exists) {
      Map data = snapshot.value as Map;
      data.forEach((key, value) {
        if (value['userId'] == _auth.currentUser!.uid) {
          posts.add(Post.fromMap(Map<String, dynamic>.from(value), key));
        }
      });
    }
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  // Delete own post
  Future<void> deletePost(String postId) async {
    if (_auth.currentUser == null) return;
    DataSnapshot snapshot = await _db.child("posts").child(postId).get();
    if (snapshot.exists) {
      Map value = snapshot.value as Map;
      if (value['userId'] == _auth.currentUser!.uid) {
        await _db.child("posts").child(postId).remove();
      }
    }
    notifyListeners();
  }
}
