import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  User? get currentUser => _auth.currentUser;

  // Check if user is remembered (works offline too)
  Future<bool> checkRememberedUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool remember = prefs.getBool('rememberMe') ?? false;

    // If user selected Remember Me → trust SharedPreferences
    if (remember) {
      return true;
    }

    // Otherwise, fall back to FirebaseAuth session
    return _auth.currentUser != null;
  }

  // Save Remember Me preference
  Future<void> setRememberMe(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', value);
  }

  // Login
  Future<String?> login(String email, String password, bool rememberMe) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await setRememberMe(rememberMe);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Signup
  Future<String?> signup(String name, String email, String password) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await cred.user!.updateDisplayName(name);

      String username = email.split('@')[0];

      AppUser appUser = AppUser(
        uid: cred.user!.uid,
        name: name,
        email: email,
        username: username,
        imageBase64: "",
        followers: 0,
        following: 0,
        postsCount: 0,
      );

      await _db.child("users").child(cred.user!.uid).set(appUser.toMap());
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Upload/Update profile image (Base64 in RTDB)
  Future<void> updateProfileImage(File imageFile, File file) async {
    if (currentUser == null) return;

    // Convert image to Base64 string
    List<int> imageBytes = await imageFile.readAsBytes();
    String base64Image = base64Encode(imageBytes);

    await _db.child("users").child(currentUser!.uid).update({
      "imageBase64": base64Image,
    });

    notifyListeners();
  }

  // Fetch user posts
  Future<List<Map<String, dynamic>>> getUserPosts(String uid) async {
    DataSnapshot snapshot = await _db
        .child("posts")
        .orderByChild("userId")
        .equalTo(uid)
        .get();

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      return data.values
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  // Get current user details
  Future<AppUser?> getCurrentUserDetails() async {
    if (currentUser == null) return null;
    DataSnapshot snapshot = await _db
        .child("users")
        .child(currentUser!.uid)
        .get();
    if (snapshot.exists) {
      return AppUser.fromMap(
        Map<String, dynamic>.from(snapshot.value as Map),
        currentUser!.uid,
      );
    }
    return null;
  }

  // Forgot Password
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Logout
  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', false);
    await _auth.signOut();
  }
}
