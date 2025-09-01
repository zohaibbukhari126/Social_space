import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../viewmodels/post_viewmodel.dart';

class NewPostView extends StatefulWidget {
  const NewPostView({super.key});

  @override
  State<NewPostView> createState() => _NewPostViewState();
}

class _NewPostViewState extends State<NewPostView> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final post = await context.read<PostViewModel>().addPost(
            _contentController.text.trim(),
            imageFile: _selectedImage,
          );

      if (mounted && post != null) {
        Navigator.pop(context, post);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔹 Fancy green AppBar
      appBar: AppBar(
        title: const Text("Create Post"),
        centerTitle: true,
        elevation: 4,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green, Colors.teal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green,
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                elevation: 3,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.green,
                      ),
                    )
                  : const Text(
                      "Post",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),

      // 🔹 Fancy Body
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Text field inside green card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextFormField(
                    controller: _contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: "What's on your mind?",
                      border: InputBorder.none,
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? "Content is required"
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Image section
              _selectedImage != null
                  ? Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Image.file(_selectedImage!,
                              height: 200, fit: BoxFit.cover),
                          Container(
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.only(right: 8, bottom: 8),
                            child: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              onPressed: () =>
                                  setState(() => _selectedImage = null),
                            ),
                          ),
                        ],
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image, color: Colors.green),
                      label: const Text(
                        "Add Image",
                        style: TextStyle(color: Colors.green),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
