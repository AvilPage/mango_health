import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pocketbase_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthSuccess, this.onSkip});

  final VoidCallback onAuthSuccess;
  final VoidCallback? onSkip;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await PocketBaseService.instance.authWithGoogle();
      widget.onAuthSuccess();
    } on ClientException catch (e) {
      setState(() => _errorMessage = _parseError(e));
    } catch (e) {
      setState(() => _errorMessage = 'Google sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (_isLogin) {
        await PocketBaseService.instance.login(
          _emailController.text,
          _passwordController.text,
        );
      } else {
        await PocketBaseService.instance.register(
          _emailController.text,
          _passwordController.text,
          _nameController.text,
        );
      }
      widget.onAuthSuccess();
    } on ClientException catch (e) {
      setState(() {
        _errorMessage = _parseError(e);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(ClientException e) {
    if (e.statusCode == 400) {
      final data = e.response['data'] as Map?;
      if (data != null) {
        final msgs = data.values
            .map((v) => (v as Map?)?['message'] as String?)
            .whereType<String>()
            .toList();
        if (msgs.isNotEmpty) return msgs.join(' ');
      }
      final msg = e.response['message'] as String?;
      if (msg != null) return msg;
    }
    if (e.statusCode == 0) return 'Cannot reach server. Check your connection.';
    return 'Error ${e.statusCode}. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _MangoLogo(),
                const SizedBox(height: 32),
                Text(
                  _isLogin ? 'Welcome back' : 'Create account',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Sign in to sync your steps and join groups'
                      : 'Start tracking steps and compete with friends',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Google sign-in
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: _GoogleIcon(),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (!_isLogin)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v?.trim().isEmpty ?? true)
                                ? 'Please enter your name'
                                : null,
                          ),
                        ),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (!_isLogin && v.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: theme.colorScheme.onErrorContainer,
                            size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isLogin ? 'Sign in' : 'Create account'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                            _isLogin = !_isLogin;
                            _errorMessage = null;
                          }),
                  child: Text(
                    _isLogin
                        ? "Don't have an account? Sign up"
                        : 'Already have an account? Sign in',
                  ),
                ),
                if (widget.onSkip != null)
                  TextButton(
                    onPressed: _isLoading ? null : widget.onSkip,
                    child: Text(
                      'Continue without account',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MangoLogo extends StatelessWidget {
  const _MangoLogo();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.directions_walk, size: 36, color: cs.onPrimaryContainer),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Simple "G" letter logo styled like Google's brand color
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF4285F4),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }
}
