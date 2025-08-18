import 'package:flutter/material.dart';
import '../views/home_view.dart';
import '../views/profile_view.dart';
import '../views/new_post_view.dart';
import '../models/post.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  // Only real screens (Home + Profile)
  final List<Widget> _screens = [
    const HomeView(),
    const ProfileView(),
  ];

  Future<void> _openNewPost(BuildContext context) async {
    final newPost = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewPostView()),
    );

    if (newPost is Post) {
      // Go back to Home tab
      setState(() {
        _selectedIndex = 0;
      });

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post uploaded successfully!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex == 0 ? 0 : 2, // 0: Home, 2: Profile
        onTap: (index) {
          if (index == 1) {
            // New Post special case
            _openNewPost(context);
          } else if (index == 2) {
            setState(() => _selectedIndex = 1); // Profile screen
          } else {
            setState(() => _selectedIndex = 0); // Home screen
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: "New Post"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
