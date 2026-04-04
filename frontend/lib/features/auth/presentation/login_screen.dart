/// Login screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';

/// Email/password login form with tenant selector.
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates a [LoginScreen].
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  String? _errorMessage;

  List<String> _tenantSlugs = [];
  String? _selectedSlug;
  bool _loadingSlugs = false;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTenants() async {
    setState(() => _loadingSlugs = true);
    try {
      final slugs =
          await ref.read(authRepositoryProvider).fetchTenantSlugs();
      setState(() {
        _tenantSlugs = slugs;
        if (slugs.isNotEmpty) _selectedSlug = slugs.first;
      });
    } catch (_) {
      // Silently ignore — user can type slug manually.
    } finally {
      setState(() => _loadingSlugs = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSlug == null || _selectedSlug!.isEmpty) {
      setState(() => _errorMessage = 'Please select a tenant.');
      return;
    }
    setState(() => _errorMessage = null);

    try {
      await ref.read(authProvider.notifier).login(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
            _selectedSlug!,
          );
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.statusCode == 401
            ? 'Invalid email or password.'
            : e.message;
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'IMS',
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inventory Management System',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  _loadingSlugs
                      ? const Center(
                          child: SizedBox(
                            height: 48,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : _tenantSlugs.isEmpty
                          ? TextFormField(
                              initialValue: _selectedSlug,
                              decoration: const InputDecoration(
                                labelText: 'Tenant',
                              ),
                              onChanged: (v) => _selectedSlug = v,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Tenant is required';
                                }
                                return null;
                              },
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedSlug,
                              decoration: const InputDecoration(
                                labelText: 'Tenant',
                              ),
                              items: _tenantSlugs
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedSlug = v),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Tenant is required';
                                }
                                return null;
                              },
                            ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(labelText: 'Email'),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Email is required';
                      }
                      if (!v.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Password is required';
                      }
                      return null;
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sign In'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
