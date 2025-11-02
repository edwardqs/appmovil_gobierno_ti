import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../risks/create_risk_screen.dart';
import '../profile/profile_screen.dart';
import 'manager_dashboard_view.dart'; // <-- IMPORTAR VISTA GERENTE
import 'auditor_dashboard_view.dart'; // <-- IMPORTAR VISTA AUDITOR

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Widget que decide qué dashboard mostrar
  Widget _buildDashboardByRole(UserRole? role) {
    if (role == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pending_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Esperando asignación de rol',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Un gerente debe asignar tu rol para acceder al dashboard',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    switch (role) {
      case UserRole.gerenteAuditoria:
        return const ManagerDashboardView();

      case UserRole.auditorJunior:
      case UserRole.auditorSenior:
        return const AuditorDashboardView();

      default:
      // Un dashboard por defecto si el rol es desconocido
        return const Center(child: Text('Rol no reconocido'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    // Si por alguna razón el usuario es nulo, muestra un loader.
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    void _logout() {
      authProvider.logout();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard GRC'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Cerrar Sesión',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                user.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(user.email),
                  const SizedBox(height: 4),
                  Text(
                    'Rol: ${user.role != null ? UserModel.roleToDisplayString(user.role!) : 'Sin rol'}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
                  ),
                ],
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: AppColors.primary),
              ),
              decoration: const BoxDecoration(color: AppColors.primary),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Mi Perfil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text('Configurar Biometría'),
              subtitle: const Text('Configurar autenticación biométrica'),
              onTap: () {
                Navigator.pop(context);
                context.go('/biometric-setup');
              },
            ),
            ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('Mis Dispositivos'),
              subtitle: const Text('Gestionar dispositivos registrados'),
              onTap: () {
                Navigator.pop(context);
                context.go('/devices');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar Sesión'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: _buildDashboardByRole(user.role), // <-- Llama al distribuidor

      // Mostrar el botón de "Nuevo Riesgo" solo a los roles que pueden registrar
      floatingActionButton: (user.role != null && 
          (user.role == UserRole.auditorJunior || user.role == UserRole.auditorSenior))
          ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const CreateRiskScreen(),
          ));
        },
        label: const Text('Nuevo Riesgo'),
        icon: const Icon(Icons.add),
      )
          : null, // No muestra el botón para otros roles
    );
  }
}