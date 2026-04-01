/// Adaptive navigation shell for the IMS app.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/inventory/providers/inventory_provider.dart';

/// A single navigation destination entry.
class _NavDestination {
  /// Creates a [_NavDestination].
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  /// Display label.
  final String label;

  /// Unselected icon.
  final IconData icon;

  /// Selected icon.
  final IconData selectedIcon;

  /// GoRouter path prefix.
  final String route;
}

List<_NavDestination> _destinationsForRole(String? role) {
  const dashboard = _NavDestination(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    route: '/dashboard',
  );
  const products = _NavDestination(
    label: 'Products',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
    route: '/products',
  );
  const inventory = _NavDestination(
    label: 'Inventory',
    icon: Icons.warehouse_outlined,
    selectedIcon: Icons.warehouse,
    route: '/inventory',
  );
  const sales = _NavDestination(
    label: 'Sales',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale,
    route: '/sales',
  );
  const users = _NavDestination(
    label: 'Users',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    route: '/users',
  );

  return switch (role) {
    'admin' => [dashboard, products, inventory, sales, users],
    'manager' => [products, inventory, sales],
    _ => [sales],
  };
}

/// Adaptive shell that wraps authenticated screens.
///
/// Renders a [NavigationRail] on desktop (≥800 px) and a
/// [NavigationDrawer] inside a [Scaffold] on mobile (<800 px).
class AppShell extends ConsumerStatefulWidget {
  /// Creates an [AppShell].
  const AppShell({super.key, required this.child});

  /// The active screen widget supplied by [ShellRoute].
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _railExtended = true;

  int _selectedIndex(
    BuildContext context,
    List<_NavDestination> destinations,
  ) {
    final location =
        GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < destinations.length; i++) {
      if (location.startsWith(destinations[i].route)) {
        return i;
      }
    }
    return 0;
  }

  void _onDestinationSelected(
    BuildContext context,
    int index,
    List<_NavDestination> destinations,
  ) {
    context.go(destinations[index].route);
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final alertCount =
        ref.watch(alertCountProvider).valueOrNull ?? 0;
    final role =
        ref.watch(authProvider).valueOrNull?.userRole;
    final destinations = _destinationsForRole(role);
    final isDesktop = ResponsiveBreakpoints.of(context)
        .largerOrEqualTo('DESKTOP');

    if (isDesktop) {
      return _DesktopShell(
        extended: _railExtended,
        selectedIndex: _selectedIndex(context, destinations),
        alertCount: alertCount,
        destinations: destinations,
        onDestinationSelected: (i) =>
            _onDestinationSelected(context, i, destinations),
        onToggleExtended: () =>
            setState(() => _railExtended = !_railExtended),
        onLogout: _logout,
        child: widget.child,
      );
    }

    return _MobileShell(
      selectedIndex: _selectedIndex(context, destinations),
      alertCount: alertCount,
      destinations: destinations,
      onDestinationSelected: (i) {
        Navigator.of(context).pop();
        _onDestinationSelected(context, i, destinations);
      },
      onLogout: _logout,
      child: widget.child,
    );
  }
}

// ── Desktop shell ────────────────────────────────────────────

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.extended,
    required this.selectedIndex,
    required this.alertCount,
    required this.destinations,
    required this.onDestinationSelected,
    required this.onToggleExtended,
    required this.onLogout,
    required this.child,
  });

  final bool extended;
  final int selectedIndex;
  final int alertCount;
  final List<_NavDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onToggleExtended;
  final VoidCallback onLogout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            backgroundColor: cs.surface,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            leading: _RailHeader(
              extended: extended,
              onToggle: onToggleExtended,
            ),
            trailing: _RailTrailing(onLogout: onLogout),
            destinations: _buildRailDestinations(
                alertCount, destinations),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  List<NavigationRailDestination> _buildRailDestinations(
    int alertCount,
    List<_NavDestination> destinations,
  ) {
    return destinations.map((d) {
      final isInventory = d.route == '/inventory';
      final badgeCount = isInventory ? alertCount : 0;
      return NavigationRailDestination(
        icon: badgeCount > 0
            ? Badge(
                label: Text('$badgeCount'),
                child: Icon(d.icon),
              )
            : Icon(d.icon),
        selectedIcon: badgeCount > 0
            ? Badge(
                label: Text('$badgeCount'),
                child: Icon(d.selectedIcon),
              )
            : Icon(d.selectedIcon),
        label: Text(d.label),
      );
    }).toList();
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader({
    required this.extended,
    required this.onToggle,
  });

  final bool extended;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          if (extended)
            SizedBox(
              width: 256,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Text(
                      'IMS',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.menu_open),
                      tooltip: 'Collapse',
                      onPressed: onToggle,
                    ),
                  ],
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Expand',
              onPressed: onToggle,
            ),
        ],
      ),
    );
  }
}

class _RailTrailing extends StatelessWidget {
  const _RailTrailing({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: onLogout,
          ),
        ),
      ),
    );
  }
}

// ── Mobile shell ─────────────────────────────────────────────

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.selectedIndex,
    required this.alertCount,
    required this.destinations,
    required this.onDestinationSelected,
    required this.onLogout,
    required this.child,
  });

  final int selectedIndex;
  final int alertCount;
  final List<_NavDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IMS')),
      drawer: NavigationDrawer(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
            child: Text('IMS'),
          ),
          ...destinations.map((d) {
            final isInventory = d.route == '/inventory';
            final count = isInventory ? alertCount : 0;
            return NavigationDrawerDestination(
              icon: count > 0
                  ? Badge(
                      label: Text('$count'),
                      child: Icon(d.icon),
                    )
                  : Icon(d.icon),
              selectedIcon: count > 0
                  ? Badge(
                      label: Text('$count'),
                      child: Icon(d.selectedIcon),
                    )
                  : Icon(d.selectedIcon),
              label: Text(d.label),
            );
          }),
          const Divider(indent: 28, endIndent: 28),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: onLogout,
          ),
        ],
      ),
      body: child,
    );
  }
}
