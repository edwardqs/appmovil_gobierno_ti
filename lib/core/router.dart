import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'locator.dart'; // <-- IMPORTACIÓN AÑADIDA
import '../presentation/providers/auth_provider.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/dashboard/dashboard_screen.dart';

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
  ],
  redirect: (BuildContext context, GoRouterState state) {
    final authProvider = context.read<AuthProvider>();
    final bool isAuthenticated = authProvider.isAuthenticated;
    final String location = state.matchedLocation;

    if (!isAuthenticated && location != '/login') {
      return '/login';
    }

    if (isAuthenticated && location == '/login') {
      return '/';
    }

    return null;
  },
);
