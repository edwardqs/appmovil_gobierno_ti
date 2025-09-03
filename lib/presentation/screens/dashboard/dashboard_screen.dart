import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/risk_provider.dart';
import '../auth/login_screen.dart';
import '../risks/create_risk_screen.dart';
import '../risks/risk_list_screen.dart';
import '../../widgets/common/kpi_card.dart';
import '../../widgets/animations/fade_in_animation.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Escucha al RiskProvider para obtener los datos de los riesgos.
    final riskProvider = Provider.of<RiskProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Cálculos para los KPIs basados en los datos del provider.
    final criticalRisks =
        riskProvider.risks.where((r) => r.inherentRisk >= 20).length;
    final highRisks = riskProvider.risks
        .where((r) => r.inherentRisk >= 13 && r.inherentRisk < 20)
        .length;
    final totalRisks = riskProvider.risks.length;

    void _logout() {
      authProvider.logout();
      // Asegurarse de que no haya pantallas anteriores en el stack.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
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
      body: riskProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () => riskProvider.fetchRisks(),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Tarjetas de KPI con animación
            FadeInAnimation(
              delay: 0.5,
              child: KpiCard(
                title: 'Riesgos Críticos',
                value: criticalRisks.toString(),
                icon: Icons.warning_amber_rounded,
                color: AppColors.error,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RiskListScreen(
                        filter: RiskStatusFilter.critical),
                  ));
                },
              ),
            ),
            const SizedBox(height: 16),
            FadeInAnimation(
              delay: 0.7,
              child: KpiCard(
                title: 'Riesgos Altos',
                value: highRisks.toString(),
                icon: Icons.dangerous_outlined,
                color: AppColors.warning,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                    const RiskListScreen(filter: RiskStatusFilter.high),
                  ));
                },
              ),
            ),
            const SizedBox(height: 16),
            FadeInAnimation(
              delay: 0.9,
              child: KpiCard(
                title: 'Total de Riesgos',
                value: totalRisks.toString(),
                icon: Icons.shield_outlined,
                color: AppColors.primary,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RiskListScreen(),
                  ));
                },
              ),
            ),
            const SizedBox(height: 24),
            FadeInAnimation(
              delay: 1.1,
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.list_alt_rounded),
                  title: const Text('Ver todos los riesgos'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const RiskListScreen(),
                    ));
                  },
                ),
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => CreateRiskScreen()));
        },
        label: const Text('Nuevo Riesgo'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

// Enum para pasar filtros a la pantalla de lista de riesgos
enum RiskStatusFilter { all, critical, high }

