/// Super admin login screen — WebAuthn hardware key flow.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/super_admin_provider.dart';

/// Screen for super admin authentication via WebAuthn hardware key.
///
/// Flow:
///  1. Enter email and press "Request Challenge".
///  2. The server returns a challenge that the hardware key must sign.
///  3. Paste the signed assertion JSON and press "Verify".
///
/// In a production web build, steps 2–3 would invoke the browser's
/// WebAuthn API (navigator.credentials.get) via JS interop. This
/// screen provides a compatible manual flow for desktop environments.
class SuperAdminLoginScreen extends ConsumerStatefulWidget {
  /// Creates a [SuperAdminLoginScreen].
  const SuperAdminLoginScreen({super.key});

  @override
  ConsumerState<SuperAdminLoginScreen> createState() =>
      _SuperAdminLoginScreenState();
}

class _SuperAdminLoginScreenState
    extends ConsumerState<SuperAdminLoginScreen> {
  final _emailController = TextEditingController();
  final _credentialController = TextEditingController();

  String? _challenge;
  Map<String, dynamic>? _options;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _credentialController.dispose();
    super.dispose();
  }

  Future<void> _requestChallenge() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(superAdminRepositoryProvider);
      final result = await repo.initiateAuthentication(email);
      setState(() {
        _options = result['options'] as Map<String, dynamic>?;
        _challenge = result['challenge'] as String?;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    final email = _emailController.text.trim();
    final credRaw = _credentialController.text.trim();
    final challenge = _challenge;

    if (credRaw.isEmpty || challenge == null) {
      setState(() {
        _error = 'Paste the signed credential JSON from your key.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final credential = jsonDecode(credRaw) as Map<String, dynamic>;
      final repo = ref.read(superAdminRepositoryProvider);
      final token = await repo.verifyAuthentication(
        email: email,
        credential: credential,
        challenge: challenge,
        origin: 'https://localhost',
      );
      await ref
          .read(superAdminAuthProvider.notifier)
          .setToken(token);
      if (mounted) context.go('/sadmin/health');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Super Admin Sign In')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.security,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hardware Key Required',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Access to the super admin panel requires '
                      'a registered FIDO2 hardware security key.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Admin Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed:
                          _loading ? null : _requestChallenge,
                      icon: const Icon(Icons.key),
                      label: const Text('Request Challenge'),
                    ),
                    if (_options != null) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Challenge issued. Sign it with your '
                        'hardware key and paste the response below.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _credentialController,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Signed Credential JSON',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loading ? null : _verify,
                        icon: const Icon(Icons.verified_user),
                        label: const Text('Verify & Sign In'),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
