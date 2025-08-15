import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../models/user.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  File? _selectedImage;
  List<Map<String, dynamic>> _userPosts = [];
  bool _isLoadingPosts = true;
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authVM = context.read<AuthViewModel>();
    final user = await authVM.getCurrentUserDetails();
    if (user != null) {
      setState(() => _user = user);
      final posts = await authVM.getUserPosts(user.uid);
      setState(() {
        _userPosts = posts;
        _isLoadingPosts = false;
      });
    } else {
      setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _selectedImage = File(pickedFile.path);
      await context.read<AuthViewModel>().updateProfileImage(_selectedImage!);
      setState(() {}); // Refresh UI
    }
  }

  Future<void> _refreshPosts() async {
    if (_user != null) {
      setState(() => _isLoadingPosts = true);
      final posts = await context.read<AuthViewModel>().getUserPosts(_user!.uid);
      setState(() {
        _userPosts = posts;
        _isLoadingPosts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    ImageProvider? profileImage;
    if (_selectedImage != null) {
      profileImage = FileImage(_selectedImage!);
    } else if (_user!.imageBase64 != null && _user!.imageBase64!.isNotEmpty) {
      profileImage = MemoryImage(base64Decode(_user!.imageBase64!));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: profileImage,
                  child: profileImage == null
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(_user!.name, style: const TextStyle(fontSize: 20)),
              Text(_user!.email, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStat("Posts", _userPosts.length),
                  _buildStat("Followers", _user!.followers),
                  _buildStat("Following", _user!.following),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              if (_isLoadingPosts)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_userPosts.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text(
                    "No posts yet.\nBe the first to post!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _userPosts.length,
                  itemBuilder: (context, index) {
                    final post = _userPosts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: post["imageBase64"] != null
                            ? Image.memory(
                                base64Decode(post["imageBase64"]),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.image_not_supported),
                        title: Text(post["title"] ?? "Untitled"),
                        subtitle: Text(post["description"] ?? "No description"),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, int value) {
    return Column(
      children: [
        Text("$value",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label),
      ],
    );
  }
}
