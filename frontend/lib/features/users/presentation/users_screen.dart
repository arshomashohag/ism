/// Users management screen — admin-only.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_user.dart';
import '../providers/users_provider.dart';
import 'widgets/user_form_dialog.dart';

/// Displays a list of tenant users with add/edit/deactivate actions.
class UsersScreen extends ConsumerWidget {
  /// Creates a [UsersScreen].
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersState = ref.watch(userListProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(userListProvider.notifier).refresh(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        onPressed: () => _addUser(context, ref),
      ),
      body: _UsersBody(usersState: usersState),
    );
  }

  Future<void> _addUser(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await UserFormDialog.show(context);
    if (result != null) {
      ref.read(userListProvider.notifier).addUser(result);
    }
  }
}

// ── Users body ────────────────────────────────────────────────

class _UsersBody extends ConsumerWidget {
  const _UsersBody({required this.usersState});

  final UserListState usersState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (usersState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (usersState.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(usersState.error!),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () =>
                  ref.read(userListProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (usersState.users.isEmpty) {
      return const Center(child: Text('No users found'));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.pixels >=
                n.metrics.maxScrollExtent - 200) {
          ref.read(userListProvider.notifier).loadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: usersState.users.length +
            (usersState.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            const SizedBox(height: 4),
        itemBuilder: (context, index) {
          if (index >= usersState.users.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _UserTile(user: usersState.users[index]);
        },
      ),
    );
  }
}

// ── User tile ─────────────────────────────────────────────────

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final initials = user.name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase())
        .take(2)
        .join();

    return Opacity(
      opacity: user.isActive ? 1.0 : 0.5,
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            child: Text(initials),
          ),
          title: Text(user.name),
          subtitle: Text(user.email),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoleChip(role: user.role),
              PopupMenuButton<_UserAction>(
                onSelected: (action) =>
                    _handleAction(context, ref, action),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _UserAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (user.isActive)
                    const PopupMenuItem(
                      value: _UserAction.deactivate,
                      child: ListTile(
                        leading:
                            Icon(Icons.person_off_outlined),
                        title: Text('Deactivate'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _UserAction action,
  ) async {
    if (action == _UserAction.edit) {
      final result =
          await UserFormDialog.show(context, user: user);
      if (result != null) {
        ref.read(userListProvider.notifier).replaceUser(result);
      }
    } else if (action == _UserAction.deactivate) {
      final confirmed = await _confirmDeactivate(context);
      if (confirmed != true) return;
      try {
        await ref
            .read(usersRepositoryProvider)
            .deleteUser(user.id);
        ref
            .read(userListProvider.notifier)
            .replaceUser(user.copyWith(isActive: false));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
  }

  Future<bool?> _confirmDeactivate(
      BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate User'),
        content: Text(
          'Deactivate ${user.name}? They will no longer '
          'be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

enum _UserAction { edit, deactivate }

// ── Role chip ─────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (role) {
      'admin' => cs.error,
      'manager' => cs.primary,
      _ => cs.secondary,
    };
    return Chip(
      label: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
