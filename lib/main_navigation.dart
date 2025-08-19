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
  int _selectedIndex = 0; // 0 = Home, 1 = Profile

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
      setState(() {
        _selectedIndex = 0; // Back to Home
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post uploaded successfully!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],

      // floating "+" button in the center
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, size: 32, color: Colors.white),
        onPressed: () => _openNewPost(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // custom bottom bar
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Home
              IconButton(
                icon: Icon(
                  Icons.home,
                  color: _selectedIndex == 0 ? Colors.blueAccent : Colors.grey,
                ),
                onPressed: () => setState(() => _selectedIndex = 0),
              ),

              const SizedBox(width: 48), // space for the FAB notch

              // Profile
              IconButton(
                icon: Icon(
                  Icons.person,
                  color: _selectedIndex == 1 ? Colors.blueAccent : Colors.grey,
                ),
                onPressed: () => setState(() => _selectedIndex = 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
