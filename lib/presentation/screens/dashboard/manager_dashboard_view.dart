// lib/presentation/screens/dashboard/manager_dashboard_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/risk_model.dart';
import '../../providers/risk_provider.dart';
import '../../widgets/animations/fade_in_animation.dart';
import '../../widgets/common/kpi_card.dart';
import '../../../core/theme/app_colors.dart';
import '../risks/risk_list_screen.dart';

class ManagerDashboardView extends StatelessWidget {
  const ManagerDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final riskProvider = Provider.of<RiskProvider>(context);

    final criticalRisks = riskProvider.risks.where((r) => r.riskLevel == 'Crítico').length;
    final highRisks = riskProvider.risks.where((r) => r.riskLevel == 'Alto').length;
    // ▼▼▼ NUEVO KPI ▼▼▼
    final pendingReviewRisks = riskProvider.risks.where((r) => r.status == RiskStatus.pendingReview).length;

    return riskProvider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
      onRefresh: () => riskProvider.fetchRisks(),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const FadeInAnimation(
            delay: 0.3,
            child: Text(
              'Resumen Gerencial',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          // ▼▼▼ NUEVA TARJETA DE KPI AÑADIDA ▼▼▼
          FadeInAnimation(
            delay: 0.5,
            child: KpiCard(
              title: 'Pendientes de Revisión',
              value: pendingReviewRisks.toString(),
              icon: Icons.rate_review_outlined,
              color: Colors.orange,
              onTap: () {
                // AÚN NO HEMOS CREADO ESTA VISTA, LO HAREMOS LUEGO
                // Por ahora, podemos navegar a la lista completa
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const RiskListScreen(),
                ));
              },
            ),
          ),
          const SizedBox(height: 16),
          FadeInAnimation(
            delay: 0.7,
            child: KpiCard(
              title: 'Riesgos Críticos',
              value: criticalRisks.toString(),
              icon: Icons.warning_amber_rounded,
              color: AppColors.criticalRisk,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const RiskListScreen(filter: RiskStatusFilter.critical),
                ));
              },
            ),
          ),
          const SizedBox(height: 16),
          FadeInAnimation(
            delay: 0.9,
            child: KpiCard(
              title: 'Riesgos Altos',
              value: highRisks.toString(),
              icon: Icons.dangerous_outlined,
              color: AppColors.highRisk,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const RiskListScreen(filter: RiskStatusFilter.high),
                ));
              },
            ),
          ),
        ],
      ),
    );
  }
}