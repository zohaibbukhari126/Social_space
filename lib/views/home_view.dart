import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quick_connect/views/login_view.dart';
import '../viewmodels/auth_viewmodel.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = context.read<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${authVM.currentUser?.displayName ?? 'User'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authVM.logout();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginView()));
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Home Screen'),
      ),
    );
  }
}
