import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'locator.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/dashboard/dashboard_screen.dart';
// ✅ RUTA CORREGIDA: Usar solo una ubicación
import '../presentation/screens/biometric_setup_screen.dart';

final GoRouter router = GoRouter(
  refreshListenable: locator<AuthProvider>(),

  routes: [
    GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/biometric-setup',
      builder: (context, state) => const BiometricSetupScreen(),
    ),
  ],

  redirect: (BuildContext context, GoRouterState state) {
    final authProvider = context.read<AuthProvider>();
    final authStatus = authProvider.status;
    final location = state.matchedLocation;

    final publicRoutes = ['/login', '/register'];
    final isPublicRoute = publicRoutes.contains(location);

    // Si está autenticado
    if (authStatus == AuthStatus.authenticated) {
      if (isPublicRoute) {
        return '/';
      }
      return null;
    }

    // Si NO está autenticado
    if (authStatus == AuthStatus.unauthenticated ||
        authStatus == AuthStatus.error) {
      if (!isPublicRoute) {
        return '/login';
      }
      return null;
    }

    // Si está cargando o inicializando, no hagas nada
    if (authStatus == AuthStatus.loading ||
        authStatus == AuthStatus.uninitialized) {
      return null;
    }

    return null;
  },
);
