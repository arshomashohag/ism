/// IMS Flutter application entrypoint.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'core/db/isar_service.dart';
import 'core/layout/app_shell.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/auth_state.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/inventory/presentation/inventory_list_screen.dart';
import 'features/inventory/presentation/transfer_screen.dart';
import 'features/products/presentation/product_detail_screen.dart';
import 'features/products/presentation/product_form_screen.dart';
import 'features/products/presentation/products_list_screen.dart';
import 'features/sales/presentation/invoice_screen.dart';
import 'features/sales/presentation/pos_screen.dart';
import 'features/sales/presentation/sales_history_screen.dart';
import 'features/analytics/presentation/dashboard_screen.dart';
import 'features/users/presentation/users_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IsarService.instance.open();
  runApp(const ProviderScope(child: ImsApp()));
}

/// Root application widget.
class ImsApp extends ConsumerStatefulWidget {
  /// Creates an [ImsApp].
  const ImsApp({super.key});

  @override
  ConsumerState<ImsApp> createState() => _ImsAppState();
}

class _ImsAppState extends ConsumerState<ImsApp> {
  /// Notified whenever auth state changes so GoRouter re-runs redirects.
  final _routerKey = ValueNotifier<int>(0);
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/',
      refreshListenable: _routerKey,
      redirect: _redirect,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegisterScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(child: child),
          routes: [
            GoRoute(
              path: '/products',
              builder: (_, __) => const ProductsListScreen(),
            ),
            GoRoute(
              path: '/products/new',
              builder: (_, __) => const ProductFormScreen(),
            ),
            GoRoute(
              path: '/products/:id',
              builder: (_, state) => ProductDetailScreen(
                productId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/products/:id/edit',
              builder: (_, state) => ProductFormScreen(
                productId: state.pathParameters['id'],
              ),
            ),
            GoRoute(
              path: '/inventory',
              builder: (_, __) =>
                  const InventoryListScreen(),
            ),
            GoRoute(
              path: '/inventory/transfer',
              builder: (_, __) => const TransferScreen(),
            ),
            GoRoute(
              path: '/sales',
              builder: (_, __) =>
                  const SalesHistoryScreen(),
            ),
            GoRoute(
              path: '/sales/pos',
              builder: (_, __) => const PosScreen(),
            ),
            GoRoute(
              path: '/sales/:id',
              builder: (_, state) => InvoiceScreen(
                saleId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/dashboard',
              builder: (_, __) =>
                  const DashboardScreen(),
            ),
            GoRoute(
              path: '/users',
              builder: (_, __) => const UsersScreen(),
            ),
          ],
        ),
      ],
    );
  }

  String? _redirect(BuildContext context, GoRouterState state) {
    final authAsync = ref.read(authProvider);
    if (authAsync.isLoading) return null;

    final authStatus = authAsync.valueOrNull?.status;
    if (authStatus == null || authStatus == AuthStatus.unknown) {
      return null;
    }

    final isAuthenticated = authStatus == AuthStatus.authenticated;
    final loc = state.matchedLocation;
    final isPublic =
        loc == '/' || loc == '/login' || loc == '/register';

    if (!isAuthenticated && !isPublic) return '/';
    if (isAuthenticated && isPublic) {
      final role = authAsync.valueOrNull?.userRole;
      return role == 'admin' ? '/dashboard' : '/products';
    }

    final auth = authAsync.valueOrNull;
    if (loc.startsWith('/dashboard') && auth?.userRole != 'admin') {
      return '/products';
    }
    if (loc.startsWith('/users') && auth?.userRole != 'admin') {
      return '/sales';
    }
    return null;
  }

  @override
  void dispose() {
    _routerKey.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authProvider, (_, __) {
      _routerKey.value++;
    });

    return MaterialApp.router(
      title: 'IMS',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: _router,
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: const [
          Breakpoint(start: 0, end: 799, name: MOBILE),
          Breakpoint(
            start: 800,
            end: double.infinity,
            name: 'DESKTOP',
          ),
        ],
      ),
    );
  }
}
