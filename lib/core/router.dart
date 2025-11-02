import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'locator.dart'; // <-- IMPORTACIÓN AÑADIDA
import '../presentation/providers/auth_provider.dart';
import '../presentation/screens/auth/login_screen.dart';

import '../presentation/screens/dashboard/dashboard_screen.dart';
import '../presentation/screens/connection_test_screen.dart';
import '../presentation/screens/test/supabase_test_screen.dart';
import '../presentation/screens/biometric_setup_screen.dart';

// Creamos una instancia del router.
final GoRouter router = GoRouter(
  refreshListenable: locator<AuthProvider>(),
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    GoRoute(
      path: '/connection-test',
      builder: (context, state) => const ConnectionTestScreen(),
    ),
    GoRoute(
      path: '/supabase-test',
      builder: (context, state) => const SupabaseTestScreen(),
    ),
    GoRoute(
      path: '/biometric-setup',
      builder: (context, state) => const BiometricSetupScreen(),
    ),
  ],
  redirect: (BuildContext context, GoRouterState state) {
    final authProvider = context.read<AuthProvider>();
    final bool isAuthenticated = authProvider.isAuthenticated;
    final String location = state.matchedLocation;

    // Permitir acceso a login sin autenticación
    final publicRoutes = ['/login'];
    
    if (!isAuthenticated && !publicRoutes.contains(location)) {
      return '/login';
    }

    if (isAuthenticated && publicRoutes.contains(location)) {
      return '/';
    }

    return null;
  },
);
