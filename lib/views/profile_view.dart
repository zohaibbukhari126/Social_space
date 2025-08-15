import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../models/post.dart';
import '../models/user.dart';
import 'login_view.dart';

class ProfileView extends StatefulWidget {
  final String? userId; // if null, show current user

  const ProfileView({super.key, this.userId});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  AppUser? userData;
  bool isLoading = true;
  List<Post> userPosts = [];
  bool isFollowing = false;

  String get profileUid =>
      widget.userId ?? FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    final ref = FirebaseDatabase.instance.ref("users/$profileUid");
    final snapshot = await ref.get();

    if (snapshot.exists) {
      AppUser user = AppUser.fromMap(
          Map<String, dynamic>.from(snapshot.value as Map), profileUid);

      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      bool following = false;
      DataSnapshot followersSnap =
          await FirebaseDatabase.instance.ref("users/$profileUid/followersList").get();
      if (followersSnap.exists) {
        Map<String, dynamic> followers =
            Map<String, dynamic>.from(followersSnap.value as Map);
        following = followers.containsKey(currentUserId);
      }

      // fetch user's posts
      DataSnapshot postsSnap = await FirebaseDatabase.instance
          .ref("posts")
          .orderByChild("userId")
          .equalTo(profileUid)
          .get();

      List<Post> posts = [];
      if (postsSnap.exists) {
        final data = Map<String, dynamic>.from(postsSnap.value as Map);
        data.forEach((key, value) {
          Map<String, dynamic> postMap = Map<String, dynamic>.from(value);
          posts.add(Post.fromMap(
            postMap,
            key,
            currentUserId: currentUserId,
            username: user.username,
            userProfileImage: user.imageBase64,
          ));
        });
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      setState(() {
        userData = user;
        isFollowing = following;
        userPosts = posts;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final userRef = FirebaseDatabase.instance.ref("users/$profileUid");
    final currentUserRef =
        FirebaseDatabase.instance.ref("users/$currentUserId");

    if (isFollowing) {
      await userRef.child("followersList/$currentUserId").remove();
      await currentUserRef.child("followingList/$profileUid").remove();
      setState(() {
        isFollowing = false;
        userData!.followers--;
      });
    } else {
      await userRef.child("followersList/$currentUserId").set(true);
      await currentUserRef.child("followingList/$profileUid").set(true);
      setState(() {
        isFollowing = true;
        userData!.followers++;
      });
    }
  }

  Future<void> _deletePost(String postId) async {
    await FirebaseDatabase.instance.ref("posts/$postId").remove();
    setState(() {
      userPosts.removeWhere((p) => p.postId == postId);
      userData!.postsCount--;
    });
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
    final authVM = context.read<AuthViewModel>();

    if (isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    if (userData == null) {
      return const Scaffold(
          body: Center(child: Text("No profile data found")));
    }

    final isCurrentUser =
        profileUid == FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(userData!.username),
        centerTitle: true,
        actions: isCurrentUser
            ? [
                PopupMenuButton<String>(
                  onSelected: (String result) {
                    if (result == 'edit') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Edit profile feature coming soon"),
                        ),
                      );
                    } else if (result == 'logout') {
                      _logout(authVM);
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit Profile'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          // Top profile info (fixed, unscrollable)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                InkWell(
                  onTap: isCurrentUser ? () {} : null,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: (userData!.imageBase64 != null &&
                                userData!.imageBase64!.isNotEmpty)
                            ? MemoryImage(base64Decode(userData!.imageBase64!))
                            : null,
                        child: (userData!.imageBase64 == null ||
                                userData!.imageBase64!.isEmpty)
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                      if (isCurrentUser)
                        Positioned(
                          bottom: 0,
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
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  userData!.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard("Posts", userData!.postsCount),
                    _buildStatCard("Followers", userData!.followers),
                    _buildStatCard("Following", userData!.following),
                  ],
                ),
                const SizedBox(height: 16),

                // Follow/Unfollow button
                if (!isCurrentUser)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? Colors.black : Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _toggleFollow,
                      child: Text(isFollowing ? "Unfollow" : "Follow"),
                    ),
                  ),
                const SizedBox(height: 16),
                const Divider(thickness: 2),
              ],
            ),
          ),

          // Posts list (scrollable)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: userPosts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final post = userPosts[index];
                return Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              post.username ?? "Unknown User",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _deletePost(post.postId);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text("Delete Post"),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(post.content),
                      ),
                      if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.memory(
                            base64Decode(post.imageUrl!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Posted on: ${post.createdAt.day.toString().padLeft(2,'0')}/"
                          "${post.createdAt.month.toString().padLeft(2,'0')}/"
                          "${post.createdAt.year.toString().substring(2)}",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
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
          "$count",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label),
      ],
    );
  }
}
