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
        _selectedIndex = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post uploaded successfully!")),
      );
    }
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: isSelected ? Colors.blueAccent : Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blueAccent : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],

      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNewPost(context),
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        elevation: 8,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Home
              _buildNavItem(Icons.home, "Home", 0),

              // Spacer for FAB
              const SizedBox(width: 48),

              // Profile
              _buildNavItem(Icons.person, "Profile", 1),
            ],
          ),
        ),
      ),
    );
  }
}
