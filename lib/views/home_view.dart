import 'package:adaptive_theme/adaptive_theme.dart';
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
    final currentMode = AdaptiveTheme.of(context).mode;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Social Space"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: PopupMenuButton<String>(
          icon: const Icon(Icons.wb_sunny_outlined, color: Colors.orange),
          onSelected: (value) {
            if (value == 'light') AdaptiveTheme.of(context).setLight();
            if (value == 'dark') AdaptiveTheme.of(context).setDark();
            if (value == 'system') AdaptiveTheme.of(context).setSystem();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'light',
              child: Row(
                children: const [
                  Icon(Icons.wb_sunny, color: Colors.amber),
                  SizedBox(width: 10),
                  Text(
                    "Light Theme",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'dark',
              child: Row(
                children: const [
                  Icon(Icons.nightlight_round, color: Colors.blueGrey),
                  SizedBox(width: 10),
                  Text(
                    "Dark Theme",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'system',
              child: Row(
                children: const [
                  Icon(Icons.settings_suggest, color: Colors.teal),
                  SizedBox(width: 10),
                  Text(
                    "System Default",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
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
                      backgroundColor: Colors.tealAccent, // changed
                      color: Colors.orange, // changed
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
                    color: Colors.teal, // changed
                    onRefresh: _refreshPosts,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text(
                            "Nothing here yet \nBe the first to share your thoughts!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ), // changed
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: Colors.teal, // changed
                  onRefresh: _refreshPosts,
                  child: ListView.separated(
                    separatorBuilder: (_, __) => const Divider(
                      thickness: 1,
                      color: Colors.tealAccent,
                    ), // changed
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
