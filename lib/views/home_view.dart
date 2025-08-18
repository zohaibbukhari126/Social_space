import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quick_connect/widgets/like_button_widget.dart';
import '../viewmodels/post_viewmodel.dart';
import '../models/post.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late Future<List<Post>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = context.read<PostViewModel>().fetchAllPosts();
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _postsFuture = context.read<PostViewModel>().fetchAllPosts();
    });
  }

  String formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year.toString().substring(2)}";
  }

  Future<void> _toggleLike(Post post) async {
    await context.read<PostViewModel>().toggleLike(post);
  }

  void showFullImage(String base64Image) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(child: Image.memory(base64Decode(base64Image))),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quick Connect"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<List<Post>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshPosts,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Text(
                      "No one has posted yet on Quick Connect.\nBe the first to post!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshPosts,
            child: ListView.separated(
              separatorBuilder: (_, __) =>
                  const Divider(thickness: 2, color: Colors.black87),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile + Username (left column)
                      Column(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: (post.userProfileImage != null &&
                                    post.userProfileImage!.isNotEmpty)
                                ? MemoryImage(
                                    base64Decode(post.userProfileImage!),
                                  )
                                : null,
                            child: (post.userProfileImage == null ||
                                    post.userProfileImage!.isEmpty)
                                ? const Icon(Icons.person, color: Colors.white, size: 18,)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      // Post content and image (right column)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.username ?? "Unknown User",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              post.content,
                              style: const TextStyle(fontSize: 16),
                            ),
                            // Image preview with tap to expand
                            if (post.imageUrl != null &&
                                post.imageUrl!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: GestureDetector(
                                  onTap: () => showFullImage(post.imageUrl!),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      base64Decode(post.imageUrl!),
                                      fit: BoxFit.cover,
                                      height: 200,
                                      width: double.infinity,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Posted on: ${formatDate(post.createdAt)}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                LikeButtonWidget(post: post, onToggle: _toggleLike),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
