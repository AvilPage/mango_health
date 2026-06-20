import 'package:flutter/material.dart';

import '../main.dart';
import '../services/database_service.dart';
import '../services/pocketbase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isSaving = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await DatabaseService.instance.getProfile();
    if (mounted) {
      setState(() {
        _nameController.text = data['name'] ??
            PocketBaseService.instance.currentUserName ?? '';
        _phoneController.text = data['phone'] ?? '';
        _emailController.text = data['email'] ??
            PocketBaseService.instance.currentUserEmail ?? '';
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
      _isSaved = false;
    });
    await DatabaseService.instance.saveProfile({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
    });
    if (mounted) {
      setState(() {
        _isSaving = false;
        _isSaved = true;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed != true) return;
    await PocketBaseService.instance.logout();
    authNotifier.value = false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final userName = PocketBaseService.instance.currentUserName;
    final userEmail = PocketBaseService.instance.currentUserEmail;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account info banner
          Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: cs.primary,
                    child: Text(
                      (userName?.isNotEmpty == true
                              ? userName![0]
                              : userEmail?[0] ?? '?')
                          .toUpperCase(),
                      style: TextStyle(
                          color: cs.onPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (userName?.isNotEmpty == true)
                          Text(userName!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  color: cs.onPrimaryContainer)),
                        if (userEmail?.isNotEmpty == true)
                          Text(userEmail!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onPrimaryContainer)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: Text(_isSaving ? 'Saving...' : 'Save'),
          ),
          if (_isSaved) ...[
            const SizedBox(height: 12),
            const Text('Profile saved.', textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

