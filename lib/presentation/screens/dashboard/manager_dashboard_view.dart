// lib/presentation/screens/dashboard/manager_dashboard_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/risk_model.dart';
import '../../providers/risk_provider.dart';
import '../../widgets/animations/fade_in_animation.dart';
import '../../widgets/common/kpi_card.dart';
import '../../../core/theme/app_colors.dart';
import '../risks/risk_list_screen.dart';
// ▼▼▼ IMPORTACIONES AÑADIDAS ▼▼▼
import '../../../data/models/user_model.dart';
import '../../../data/services/audit_service.dart';

class ManagerDashboardView extends StatefulWidget {
  const ManagerDashboardView({super.key});

  @override
  State<ManagerDashboardView> createState() => _ManagerDashboardViewState();
}

class _ManagerDashboardViewState extends State<ManagerDashboardView> {
  // ▼▼▼ LÓGICA AÑADIDA ▼▼▼
  final AuditService _auditService = AuditService();
  late Future<List<UserModel>> _auditorsFuture;

  @override
  void initState() {
    super.initState();
    // Cargar datos de forma lazy después de que el widget se haya construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final riskProvider = Provider.of<RiskProvider>(context, listen: false);
      riskProvider.ensureRisksLoaded();
    });

    // ▼▼▼ LÓGICA AÑADIDA ▼▼▼
    _loadAuditors();
  }

  void _loadAuditors() {
    setState(() {
      _auditorsFuture = _auditService.getAvailableAuditors();
    });
  }

  Future<void> _refreshAllData() async {
    // Refrescar riesgos
    await Provider.of<RiskProvider>(context, listen: false).fetchRisks();
    // Refrescar auditores
    _loadAuditors();
  }
  // ▲▲▲ FIN DE LÓGICA AÑADIDA ▲▲▲

  @override
  Widget build(BuildContext context) {
    final riskProvider = Provider.of<RiskProvider>(context);

    final criticalRisks = riskProvider.risks.where((r) => r.riskLevel == 'Crítico').length;
    final highRisks = riskProvider.risks.where((r) => r.riskLevel == 'Alto').length;
    final pendingReviewRisks = riskProvider.risks.where((r) => r.status == RiskStatus.pendingReview).length;

    return riskProvider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
      onRefresh: _refreshAllData, // <-- MODIFICADO
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
          // ... (KPI Cards existentes sin cambios) ...
          FadeInAnimation(
            delay: 0.5,
            child: KpiCard(
              title: 'Pendientes de Revisión',
              value: pendingReviewRisks.toString(),
              icon: Icons.rate_review_outlined,
              color: Colors.orange,
              onTap: () {
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

          // ▼▼▼ NUEVA SECCIÓN DE AUDITORES AÑADIDA ▼▼▼
          const SizedBox(height: 32),
          FadeInAnimation(
            delay: 1.1,
            child: Text(
              'Auditores Disponibles (Senior)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 16),
          FadeInAnimation(
            delay: 1.3,
            child: FutureBuilder<List<UserModel>>(
              future: _auditorsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar auditores: ${snapshot.error}'));
                }

                final auditors = snapshot.data;

                if (auditors == null || auditors.isEmpty) {
                  return const Center(child: Text('No hay auditores senior disponibles.'));
                }

                // Usamos un Card para que la lista tenga un fondo
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListView.builder(
                    shrinkWrap: true, // Para que quepa dentro del ListView principal
                    physics: const NeverScrollableScrollPhysics(), // Desactiva scroll anidado
                    itemCount: auditors.length,
                    itemBuilder: (context, index) {
                      final auditor = auditors[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text(
                            auditor.name.isNotEmpty ? auditor.name[0] : 'A',
                            style: const TextStyle(color: AppColors.primary),
                          ),
                        ),
                        title: Text(auditor.name),
                        subtitle: Text(auditor.email),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Siguiente paso: Asignar a ${auditor.name}')),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}