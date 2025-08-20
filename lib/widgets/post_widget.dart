import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../viewmodels/post_viewmodel.dart';
import '../widgets/like_button_widget.dart';
import '../views/profile_view.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostWidget extends StatelessWidget {
  final Post post;
  final VoidCallback? onRefresh;
  final bool showDeleteOption;
  final Function(String)? onDelete;

  const PostWidget({
    super.key,
    required this.post,
    this.onRefresh,
    this.showDeleteOption = false,
    this.onDelete,
  });

  String formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year.toString().substring(2)}";
  }

  Future<void> _toggleLike(BuildContext context, Post post) async {
    await context.read<PostViewModel>().toggleLike(post);
  }

  void showFullImage(BuildContext context, String base64Image) {
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

  void _showDeleteConfirmation(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                
                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text("Deleting post..."),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );

                // Delete the post
                final success = await context.read<PostViewModel>().deletePost(postId);
                
                if (success) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text("✅ Post deleted successfully"),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  
                  // Call the onDelete callback if provided (for ProfileView)
                  if (onDelete != null) {
                    onDelete!(postId);
                  }
                } else {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.error, color: Colors.white),
                          SizedBox(width: 8),
                          Text("❌ Failed to delete post"),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentUserPost = FirebaseAuth.instance.currentUser?.uid == post.userId;
    
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileView(userId: post.userId),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: (post.userProfileImage != null &&
                              post.userProfileImage!.isNotEmpty)
                          ? MemoryImage(base64Decode(post.userProfileImage!))
                          : null,
                      child: (post.userProfileImage == null ||
                              post.userProfileImage!.isEmpty)
                          ? const Icon(Icons.person, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileView(userId: post.userId),
                              ),
                            );
                          },
                          child: Text(
                            post.username ?? "Unknown User",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          post.content,
                          textAlign: TextAlign.justify,
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: GestureDetector(
                              onTap: () => showFullImage(context, post.imageUrl!),
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
                      ],
                    ),
                  ),
                ],
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
                  // Always get the latest post data from PostViewModel for like status
                  Selector<PostViewModel, Post?>(
                    selector: (context, postVM) => postVM.getPostById(post.postId),
                    builder: (context, currentPost, child) {
                      // Use the current post from PostViewModel if available, otherwise fallback to the passed post
                      final postToUse = currentPost ?? post;
                      
                      return LikeButtonWidget(
                        post: postToUse,
                        onToggle: (post) => _toggleLike(context, post),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Delete option for current user's posts (only show if enabled)
        if (showDeleteOption && isCurrentUserPost)
          Positioned(
            top: 8,
            right: 16,
            child: PopupMenuButton<String>(
              onSelected: (String result) {
                if (result == 'delete') {
                  _showDeleteConfirmation(context, post.postId);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
              icon: const Icon(
                Icons.more_vert,
                color: Colors.grey,
              ),
            ),
          ),
      ],
    );
  }
}

