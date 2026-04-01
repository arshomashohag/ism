/// Dialog for creating or editing a user.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/app_user.dart';
import '../../providers/users_provider.dart';

/// Modal dialog for creating or editing a user account.
class UserFormDialog extends ConsumerStatefulWidget {
  /// Creates a [UserFormDialog].
  const UserFormDialog({super.key, this.user});

  /// When non-null, the dialog is in edit mode.
  final AppUser? user;

  /// Show the dialog and return the created/updated [AppUser].
  static Future<AppUser?> show(
    BuildContext context, {
    AppUser? user,
  }) {
    return showDialog<AppUser>(
      context: context,
      builder: (_) => UserFormDialog(user: user),
    );
  }

  @override
  ConsumerState<UserFormDialog> createState() =>
      _UserFormDialogState();
}

class _UserFormDialogState
    extends ConsumerState<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = 'salesman';
  bool _isSubmitting = false;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameCtrl.text = widget.user!.name;
      _role = widget.user!.role;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(usersRepositoryProvider);
      final AppUser result;
      if (_isEditing) {
        result = await repo.updateUser(
          widget.user!.id,
          name: _nameCtrl.text.trim(),
          role: _role,
        );
      } else {
        result = await repo.createUser(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          role: _role,
        );
      }
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit User' : 'Add User'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Email'),
                  keyboardType:
                      TextInputType.emailAddress,
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
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Password'),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Password is required';
                    }
                    if (v.length < 8) {
                      return 'Minimum 8 characters';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _role,
                decoration:
                    const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Admin'),
                  ),
                  DropdownMenuItem(
                    value: 'manager',
                    child: Text('Manager'),
                  ),
                  DropdownMenuItem(
                    value: 'salesman',
                    child: Text('Salesman'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _role = v);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2),
                )
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
