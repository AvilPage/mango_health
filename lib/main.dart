import 'package:flutter/material.dart';

import 'config.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'services/database_service.dart';
import 'services/pocketbase_service.dart';

final ValueNotifier<bool> authNotifier = ValueNotifier(false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.database;
  await PocketBaseService.instance.init(kPocketBaseUrl);
  authNotifier.value = PocketBaseService.instance.isAuthenticated;
  runApp(const MangoHealthApp());
}

class MangoHealthApp extends StatefulWidget {
  const MangoHealthApp({super.key});

  @override
  State<MangoHealthApp> createState() => _MangoHealthAppState();
}

class _MangoHealthAppState extends State<MangoHealthApp> {
  // Show auth screen on first load if not signed in; dismissed after skip/login
  bool _authDismissed = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mango Health',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        scaffoldBackgroundColor: const Color(0xFFF6FBF6),
      ),
      home: ValueListenableBuilder<bool>(
        valueListenable: authNotifier,
        builder: (context, isAuthenticated, _) {
          if (!isAuthenticated && !_authDismissed) {
            return AuthScreen(
              onAuthSuccess: () => authNotifier.value = true,
              onSkip: () => setState(() => _authDismissed = true),
            );
          }
          return MainShell(isAuthenticated: isAuthenticated);
        },
      ),
    );
  }
}

