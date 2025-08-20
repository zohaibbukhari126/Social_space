import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quick_connect/main_navigation.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/post_viewmodel.dart';
import 'views/login_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => PostViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quick Connect',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const StartupView(),
    );
  }
}

class StartupView extends StatefulWidget {
  const StartupView({super.key});

  @override
  State<StartupView> createState() => _StartupViewState();
}

class _StartupViewState extends State<StartupView> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    final authVM = context.read<AuthViewModel>();
    
    // First, check the remember me preference and handle accordingly
    await authVM.checkRememberMeOnStart();
    
    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while initializing
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // After initialization, listen to auth state changes
    return Consumer<AuthViewModel>(
      builder: (context, authVM, child) {
        return StreamBuilder<User?>(
          stream: authVM.authStateChanges,
          builder: (context, snapshot) {
            // Show loading while waiting for auth state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Show error if there's an auth error
            if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        "Authentication Error",
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text("${snapshot.error}"),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Retry initialization
                          setState(() => _isInitializing = true);
                          _initializeAuth();
                        },
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Navigate based on auth state
            if (snapshot.hasData) {
              // User is logged in
              return const MainNavigation();
            } else {
              // User is not logged in
              return const LoginView();
            }
          },
        );
      },
    );
  }
}

