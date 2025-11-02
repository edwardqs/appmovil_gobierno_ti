// lib/presentation/screens/dashboard/auditor_dashboard_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/risk_provider.dart';
import '../../widgets/common/risk_list_item.dart';
import '../risks/risk_detail_screen.dart';

class AuditorDashboardView extends StatefulWidget {
  const AuditorDashboardView({super.key});

  @override
  State<AuditorDashboardView> createState() => _AuditorDashboardViewState();
}

class _AuditorDashboardViewState extends State<AuditorDashboardView> {
  @override
  void initState() {
    super.initState();
    // Cargar datos de forma lazy después de que el widget se haya construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final riskProvider = Provider.of<RiskProvider>(context, listen: false);
      riskProvider.ensureRisksLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final riskProvider = Provider.of<RiskProvider>(context);
    final currentUser = Provider.of<AuthProvider>(context).currentUser;

    // Filtra la lista para mostrar solo los riesgos asignados al usuario actual
    final myAssignedRisks = riskProvider.risks
        .where((risk) => risk.assignedUserId == currentUser?.id)
        .toList();

    return riskProvider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
      onRefresh: () => riskProvider.fetchRisks(),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Mis Tareas Asignadas (${myAssignedRisks.length})',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          if (myAssignedRisks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('No tienes riesgos asignados.'),
              ),
            )
          else
          // Reutilizamos el widget RiskListItem que ya creamos
            ...myAssignedRisks.map((risk) {
              return RiskListItem(
                risk: risk,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RiskDetailScreen(risk: risk),
                  ));
                },
              );
            }).toList(),
        ],
      ),
    );
  }
}