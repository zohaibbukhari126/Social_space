import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quick_connect/viewmodels/post_viewmodel.dart';
import 'dart:io';
import '../viewmodels/auth_viewmodel.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../widgets/post_widget.dart';
import 'login_view.dart';
import '../widgets/gradient_button.dart';

class ProfileView extends StatefulWidget {
  final String? userId; // if null, show current user

  const ProfileView({super.key, this.userId});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  AppUser? userData;
  bool isLoading = true;
  late AuthViewModel authVM;
  late PostViewModel postVM;

  // ValueNotifiers for counts and follow status
  late ValueNotifier<int> followersCountNotifier;
  late ValueNotifier<bool> isFollowingNotifier;
  late ValueNotifier<bool> followButtonLoadingNotifier;

  String get profileUid =>
      widget.userId ?? FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    authVM = context.read<AuthViewModel>();
    postVM = context.read<PostViewModel>();
    followersCountNotifier = ValueNotifier(0);
    isFollowingNotifier = ValueNotifier(false);
    followButtonLoadingNotifier = ValueNotifier(false);
    _fetchProfileData();
  }

  @override
  void dispose() {
    followersCountNotifier.dispose();
    isFollowingNotifier.dispose();
    followButtonLoadingNotifier.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileData() async {
    final ref = FirebaseDatabase.instance.ref("users/$profileUid");
    final snapshot = await ref.get();

    if (!mounted) return;

    if (snapshot.exists) {
      AppUser user = AppUser.fromMap(
        Map<String, dynamic>.from(snapshot.value as Map),
        profileUid,
      );

      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      bool following = false;
      int followersCount = 0;
      int followingCount = 0;

      // Get followers
      DataSnapshot followersSnap = await FirebaseDatabase.instance
          .ref("users/$profileUid/followersList")
          .get();
      if (!mounted) return;
      if (followersSnap.exists) {
        Map<String, dynamic> followers = Map<String, dynamic>.from(
          followersSnap.value as Map,
        );
        followersCount = followers.length;
        following = followers.containsKey(currentUserId);
      }

      // Get following
      DataSnapshot followingSnap = await FirebaseDatabase.instance
          .ref("users/$profileUid/followingList")
          .get();
      if (!mounted) return;
      if (followingSnap.exists) {
        Map<String, dynamic> followingMap = Map<String, dynamic>.from(
          followingSnap.value as Map,
        );
        followingCount = followingMap.length;
      }

      if (!mounted) return;
      setState(() {
        userData = user;
        isLoading = false;
      });

      // Set ValueNotifiers
      followersCountNotifier.value = followersCount;
      isFollowingNotifier.value = following;
      userData!.following = followingCount; // following count can remain static
    } else {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  // Get user posts from global PostViewModel instead of local state
  List<Post> get userPosts {
    return postVM.allPosts.where((post) => post.userId == profileUid).toList();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);

    // Convert to base64
    final bytes = await imageFile.readAsBytes();
    final newImageBase64 = base64Encode(bytes);

    // Update local UI immediately (profile header only)
    if (!mounted) return;
    setState(() {
      userData!.imageBase64 = newImageBase64;
    });

    try {
      // Update profile image through AuthViewModel
      final error = await authVM.updateProfileImage(imageFile);
      
      if (error != null) {
        throw Exception(error);
      }

      // Update the profile image in all posts globally through PostViewModel
      await postVM.updateUserProfileImageInPosts(
        FirebaseAuth.instance.currentUser!.uid, 
        newImageBase64
      );

      // Update base64 string in Realtime Database
      await FirebaseDatabase.instance
          .ref()
          .child("users")
          .child(FirebaseAuth.instance.currentUser!.uid)
          .update({"imageBase64": newImageBase64});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text("✅ Profile photo updated everywhere!"),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Revert local changes if upload failed
      setState(() {
        _fetchProfileData(); // Refresh to get the correct data
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text("❌ Failed to upload photo: $e")),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showProfileImageDialog({bool isCurrentUser = true}) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 150,
                backgroundImage:
                    (userData!.imageBase64 != null &&
                        userData!.imageBase64!.isNotEmpty)
                    ? MemoryImage(base64Decode(userData!.imageBase64!))
                    : null,
                child:
                    (userData!.imageBase64 == null ||
                        userData!.imageBase64!.isEmpty)
                    ? const Icon(Icons.person, size: 100)
                    : null,
              ),
              if (isCurrentUser) ...[
                const SizedBox(height: 12),
                IconButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _pickAndUploadImage();
                  },
                  icon: const Icon(Icons.edit, size: 28, color: Colors.white),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleFollow() async {
    if (followButtonLoadingNotifier.value) return; // prevent double click
    followButtonLoadingNotifier.value = true;

    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final userRef = FirebaseDatabase.instance.ref("users/$profileUid");
    final currentUserRef = FirebaseDatabase.instance.ref(
      "users/$currentUserId",
    );

    // Optimistically update UI
    final wasFollowing = isFollowingNotifier.value;
    isFollowingNotifier.value = !wasFollowing;
    followersCountNotifier.value += wasFollowing ? -1 : 1;

    try {
      if (wasFollowing) {
        await userRef.child("followersList/$currentUserId").remove();
        await currentUserRef.child("followingList/$profileUid").remove();
      } else {
        await userRef.child("followersList/$currentUserId").set(true);
        await currentUserRef.child("followingList/$profileUid").set(true);
      }
    } catch (e) {
      // revert UI in case of error
      isFollowingNotifier.value = wasFollowing;
      followersCountNotifier.value += wasFollowing ? 1 : -1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update follow status: $e")),
      );
    } finally {
      followButtonLoadingNotifier.value = false;
    }
  }

  // Handle post deletion - no need for local state management
  void _handlePostDelete(String postId) {
    // PostViewModel already handles the deletion globally
    // Just update the post count in userData if needed
    if (userData != null) {
      setState(() {
        userData!.postsCount = (userData!.postsCount > 0) ? userData!.postsCount - 1 : 0;
      });
    }
  }

  void _logout(AuthViewModel authVM) async {
    await authVM.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginView()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (userData == null) {
      return const Scaffold(body: Center(child: Text("No profile data found")));
    }

    final isCurrentUser = profileUid == FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(userData!.username),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: isCurrentUser
            ? [
                PopupMenuButton<String>(
                  onSelected: (String result) {
                    if (result == 'logout') {
                      _logout(authVM);
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, color: Colors.red),
                              SizedBox(width: 4),
                              Text(
                                'Logout',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          // Profile header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row with Profile Pic + Name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () =>
                          _showProfileImageDialog(isCurrentUser: isCurrentUser),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage:
                                (userData!.imageBase64 != null &&
                                    userData!.imageBase64!.isNotEmpty)
                                ? MemoryImage(
                                    base64Decode(userData!.imageBase64!),
                                  )
                                : null,
                            child:
                                (userData!.imageBase64 == null ||
                                    userData!.imageBase64!.isEmpty)
                                ? const Icon(Icons.person, size: 30)
                                : null,
                          ),
                          if (isCurrentUser &&
                              (userData!.imageBase64 == null ||
                                  userData!.imageBase64!.isEmpty))
                            Positioned(
                              bottom: 1,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        userData!.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Stats row - use Selector to get real-time post count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Selector<PostViewModel, int>(
                      selector: (context, postVM) => postVM.allPosts
                          .where((post) => post.userId == profileUid)
                          .length,
                      builder: (context, postCount, child) =>
                          _buildStatCard("Posts", postCount),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: followersCountNotifier,
                      builder: (_, value, __) =>
                          _buildStatCard("Followers", value),
                    ),
                    _buildStatCard("Following", userData!.following),
                  ],
                ),

                const SizedBox(height: 16),

                // Follow button (if not current user)
                if (!isCurrentUser)
                  ValueListenableBuilder<bool>(
                    valueListenable: isFollowingNotifier,
                    builder: (_, isFollowing, __) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: followButtonLoadingNotifier,
                        builder: (_, isLoading, __) {
                          return GradientButton(
                            text: isFollowing ? "Unfollow" : "Follow",
                            onPressed: isLoading ? null : _toggleFollow,
                            isLoading: isLoading,
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
          const Divider(
            thickness: 2,
            color: Colors.black87,
            indent: 0,
            endIndent: 0,
          ),

          // Posts list using Selector to get posts from global PostViewModel
          Expanded(
            child: Selector<PostViewModel, List<Post>>(
              selector: (context, postVM) => postVM.allPosts
                  .where((post) => post.userId == profileUid)
                  .toList(),
              builder: (context, userPosts, child) {
                if (userPosts.isEmpty) {
                  return const Center(
                    child: Text(
                      "No posts yet",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: userPosts.length,
                  separatorBuilder: (_, __) =>
                      const Divider(thickness: 1, color: Colors.grey),
                  itemBuilder: (context, index) {
                    final post = userPosts[index];

                    return PostWidget(
                      key: ValueKey(post.postId),
                      post: post,
                      onRefresh: _fetchProfileData,
                      showDeleteOption: true, // Enable delete option in ProfileView
                      onDelete: _handlePostDelete, // Handle local state update
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

