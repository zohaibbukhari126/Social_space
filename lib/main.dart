import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'views/login_view.dart';
import 'views/home_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
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

class StartupView extends StatelessWidget {
  const StartupView({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = context.read<AuthViewModel>();

    return FutureBuilder<bool>(
      future: authVM.checkRememberedUser(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return const HomeView();
        } else {
          return const LoginView();
        }
      },
    );
  }
}
