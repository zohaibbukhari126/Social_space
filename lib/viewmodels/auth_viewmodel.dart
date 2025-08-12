import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  User? get currentUser => _auth.currentUser;

  // Check if user is remembered
  Future<bool> checkRememberedUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool remember = prefs.getBool('rememberMe') ?? false;

    User? user = _auth.currentUser;
    if (remember && user != null) {
      try {
        await user.reload(); // Refresh token
        return _auth.currentUser != null;
      } catch (_) {
        return false;
      }
    }
    return false;
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

  // Signup with Name & Save to Realtime Database
  Future<String?> signup(String name, String email, String password) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await cred.user!.updateDisplayName(name);

      // Save user profile in Realtime Database
      await _db.child("users").child(cred.user!.uid).set({
        "name": name,
        "email": email,
        "createdAt": DateTime.now().toIso8601String(),
      });

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
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
