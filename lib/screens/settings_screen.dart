import 'package:flutter/material.dart';

import '../services/pocketbase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PocketBaseService _pocketBaseService = PocketBaseService.instance;
  late final TextEditingController _urlController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSaving = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: _pocketBaseService.configuredUrl ?? '',
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveAndConnect() async {
    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      _pocketBaseService.configure(_urlController.text);

      if (!_pocketBaseService.isConfigured) {
        setState(() {
          _statusMessage = 'PocketBase URL cleared. Offline-only mode is active.';
        });
        return;
      }

      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _statusMessage = 'PocketBase saved. Add login details when you are ready to sync.';
        });
        return;
      }

      await _pocketBaseService.login(email, password);
      setState(() {
        _statusMessage = 'Connected to PocketBase.';
      });
    } catch (error) {
      setState(() {
        _statusMessage = 'Could not connect to PocketBase.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('PocketBase settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Connection', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    _pocketBaseService.isAuthenticated
                        ? 'Status: Connected'
                        : _pocketBaseService.isConfigured
                            ? 'Status: Configured'
                            : 'Status: Offline only',
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_statusMessage!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'PocketBase URL',
              hintText: 'http://127.0.0.1:8090',
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
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveAndConnect,
            icon: const Icon(Icons.cloud_done_outlined),
            label: Text(_isSaving ? 'Connecting...' : 'Save & Connect'),
          ),
        ],
      ),
    );
  }
}
