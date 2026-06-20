import 'package:flutter/material.dart';

import '../main.dart';
import 'auth_screen.dart';
import 'groups_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.isAuthenticated});

  final bool isAuthenticated;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      widget.isAuthenticated
          ? const GroupsScreen()
          : _AuthPromptScreen(
              icon: Icons.group_outlined,
              message: 'Sign in to create groups and see your friends\' step counts.',
              onSignInTap: () => setState(() => _selectedIndex = 2),
            ),
      widget.isAuthenticated
          ? const ProfileScreen()
          : AuthScreen(onAuthSuccess: () => authNotifier.value = true),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_walk_outlined),
            selectedIcon: Icon(Icons.directions_walk),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _AuthPromptScreen extends StatelessWidget {
  const _AuthPromptScreen({
    required this.icon,
    required this.message,
    required this.onSignInTap,
  });

  final IconData icon;
  final String message;
  final VoidCallback onSignInTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: cs.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                message,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Sign in / Create account'),
                onPressed: onSignInTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
