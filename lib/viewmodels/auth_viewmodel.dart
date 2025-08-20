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

  // Firebase auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Remember Me
  Future<void> _setRememberMePreference(bool value) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rememberMe', value);
    } catch (e) {
      debugPrint("Error saving RememberMe preference: $e");
    }
  }

  Future<bool> _getRememberMePreference() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool('rememberMe') ?? false;
    } catch (e) {
      debugPrint("Error fetching RememberMe preference: $e");
      return false;
    }
  }

  // Ensure session rules (call this in main.dart before showing Home/Login)
  Future<void> checkRememberMeOnStart() async {
    try {
      bool rememberMe = await _getRememberMePreference();
      if (!rememberMe && currentUser != null) {
        // If user is logged in but 'rememberMe' was false, log them out.
        // This handles cases where user explicitly chose NOT to be remembered.
        await logout();
      } else if (rememberMe && currentUser == null) {
        // If 'rememberMe' was true but no user is logged in (e.g., token expired),
        // clear the preference. This might happen if Firebase token expires
        // and auto-login fails, but the preference is still true.
        await _setRememberMePreference(false);
      }
    } catch (e) {
      debugPrint("Error in checkRememberMeOnStart: $e");
      // If there's an error, clear the preference to be safe
      await _setRememberMePreference(false);
    }
  }

  // Login with enhanced error handling
  Future<String?> login(String email, String password, bool rememberMe) async {
    try {
      // Validate inputs
      if (email.trim().isEmpty || password.trim().isEmpty) {
        return "Email and password cannot be empty";
      }

      // Attempt login
      await _auth.signInWithEmailAndPassword(
        email: email.trim(), 
        password: password
      );
      
      // Save user's choice only after successful login
      await _setRememberMePreference(rememberMe);
      return null; // success
    } on FirebaseAuthException catch (e) {
      debugPrint("FirebaseAuthException: ${e.code} - ${e.message}");
      
      switch (e.code) {
        case 'user-not-found':
          return "No user found with this email address";
        case 'wrong-password':
          return "Incorrect password";
        case 'invalid-email':
          return "Invalid email address format";
        case 'user-disabled':
          return "This account has been disabled";
        case 'too-many-requests':
          return "Too many failed attempts. Please try again later";
        case 'network-request-failed':
          return "No internet connection. Please try again";
        case 'invalid-credential':
          return "Invalid email or password. Please check your credentials";
        default:
          return e.message ?? "Authentication failed";
      }
    } on SocketException {
      return "No internet connection. Please try again";
    } catch (e) {
      debugPrint("Unexpected login error: $e");
      return "Unexpected error occurred. Please try again";
    }
  }

  // Signup with enhanced error handling
  Future<String?> signup(String name, String email, String password) async {
    try {
      // Validate inputs
      if (name.trim().isEmpty || email.trim().isEmpty || password.trim().isEmpty) {
        return "All fields are required";
      }

      if (password.length < 6) {
        return "Password must be at least 6 characters long";
      }

      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await cred.user!.updateDisplayName(name.trim());
      String username = email.split('@')[0];

      AppUser appUser = AppUser(
        uid: cred.user!.uid,
        name: name.trim(),
        email: email.trim(),
        username: username,
        imageBase64: "",
        followers: 0,
        following: 0,
        postsCount: 0,
      );

      await _db.child("users").child(cred.user!.uid).set(appUser.toMap());
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint("FirebaseAuthException during signup: ${e.code} - ${e.message}");
      
      switch (e.code) {
        case 'email-already-in-use':
          return "An account already exists with this email";
        case 'invalid-email':
          return "Invalid email address format";
        case 'weak-password':
          return "Password is too weak. Please choose a stronger password";
        case 'network-request-failed':
          return "No internet connection. Please try again";
        default:
          return e.message ?? "Signup failed";
      }
    } on SocketException {
      return "No internet connection. Please try again";
    } catch (e) {
      debugPrint("Unexpected signup error: $e");
      return "Unexpected error occurred. Please try again";
    }
  }

  // Enhanced profile image update with global notification
  Future<String?> updateProfileImage(File imageFile) async {
    try {
      if (currentUser == null) return "User not logged in";

      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // Update user profile in database
      await _db.child("users").child(currentUser!.uid).update({
        "imageBase64": base64Image,
      });

      // Notify all listeners that profile image has been updated
      // This will trigger rebuilds in any widget listening to AuthViewModel
      notifyListeners();
      
      return null;
    } on SocketException {
      return "No internet connection. Please try again";
    } catch (e) {
      debugPrint("Error updating profile image: $e");
      return "Failed to update image. Please try again";
    }
  }

  // Method to get current user's profile image
  Future<String?> getCurrentUserProfileImage() async {
    try {
      if (currentUser == null) return null;
      
      DataSnapshot snapshot = await _db.child("users").child(currentUser!.uid).get();
      if (snapshot.exists && snapshot.value is Map) {
        final userData = Map<String, dynamic>.from(snapshot.value as Map);
        return userData['imageBase64'] as String?;
      }
    } catch (e) {
      debugPrint("Error fetching current user profile image: $e");
    }
    return null;
  }

  // Fetch user posts
  Future<List<Map<String, dynamic>>> getUserPosts(String uid) async {
    try {
      DataSnapshot snapshot = await _db
          .child("posts")
          .orderByChild("userId")
          .equalTo(uid)
          .get();

      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return data.values
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (e) {
      debugPrint("Error fetching user posts: $e");
    }
    return [];
  }

  // Get current user details
  Future<AppUser?> getCurrentUserDetails() async {
    try {
      if (currentUser == null) return null;
      DataSnapshot snapshot =
          await _db.child("users").child(currentUser!.uid).get();
      if (snapshot.exists && snapshot.value is Map) {
        return AppUser.fromMap(
          Map<String, dynamic>.from(snapshot.value as Map),
          currentUser!.uid,
        );
      }
    } catch (e) {
      debugPrint("Error fetching user details: $e");
    }
    return null;
  }

  // Forgot Password with enhanced error handling
  Future<String?> sendPasswordReset(String email) async {
    try {
      if (email.trim().isEmpty) {
        return "Email address is required";
      }

      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint("FirebaseAuthException during password reset: ${e.code} - ${e.message}");
      
      switch (e.code) {
        case 'user-not-found':
          return "No user found with this email address";
        case 'invalid-email':
          return "Invalid email address format";
        case 'network-request-failed':
          return "No internet connection. Please try again";
        default:
          return e.message ?? "Password reset failed";
      }
    } on SocketException {
      return "No internet connection. Please try again";
    } catch (e) {
      debugPrint("Unexpected password reset error: $e");
      return "Unexpected error occurred. Please try again";
    }
  }

  // Logout with enhanced error handling
  Future<void> logout() async {
    try {
      // When logging out, always set rememberMe to false
      await _setRememberMePreference(false);
      await _auth.signOut();
    } catch (e) {
      debugPrint("Error logging out: $e");
      // Even if there's an error, try to clear the preference
      try {
        await _setRememberMePreference(false);
      } catch (prefError) {
        debugPrint("Error clearing remember me preference: $prefError");
      }
    }
  }

  // Helper method to check if user is properly authenticated
  Future<bool> isUserAuthenticated() async {
    try {
      User? user = currentUser;
      if (user == null) return false;
      
      // Try to refresh the token to ensure it's still valid
      await user.getIdToken(true);
      return true;
    } catch (e) {
      debugPrint("User authentication check failed: $e");
      return false;
    }
  }
}

