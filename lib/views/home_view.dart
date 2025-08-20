import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/post_viewmodel.dart';
import '../models/post.dart';
import '../widgets/post_widget.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    // Fetch posts when the view initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostViewModel>().fetchAllPosts();
    });
  }

  Future<void> _refreshPosts() async {
    await context.read<PostViewModel>().refreshPosts();
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
      body: Column(
        children: [
          // Loading indicator - only rebuild this part when loading state changes
          Selector<PostViewModel, bool>(
            selector: (context, postVM) => postVM.isLoading,
            builder: (context, isLoading, child) {
              return isLoading
                  ? const LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: Colors.grey,
                      color: Colors.deepPurple,
                    )
                  : const SizedBox.shrink();
            },
          ),
          
          // Posts list - only rebuild when posts list changes
          Expanded(
            child: Selector<PostViewModel, List<Post>>(
              selector: (context, postVM) => postVM.allPosts,
              builder: (context, posts, child) {
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
                        const Divider(thickness: 1, color: Colors.grey),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      
                      // Each PostWidget is independent and will only rebuild
                      // when its specific post data changes
                      return PostWidget(
                        key: ValueKey(post.postId),
                        post: post,
                        onRefresh: _refreshPosts,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

