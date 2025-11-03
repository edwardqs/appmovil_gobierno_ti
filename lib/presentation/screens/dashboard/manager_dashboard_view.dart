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

          // ▼▼▼ SECCIÓN MEJORADA DE AUDITORES SENIOR ▼▼▼
          const SizedBox(height: 32),
          FadeInAnimation(
            delay: 1.1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Auditores Senior Disponibles',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadAuditors,
                  tooltip: 'Actualizar lista de auditores',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FadeInAnimation(
            delay: 1.3,
            child: FutureBuilder<List<UserModel>>(
              future: _auditorsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                          const SizedBox(height: 8),
                          Text('Error al cargar auditores: ${snapshot.error}'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadAuditors,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final auditors = snapshot.data;

                if (auditors == null || auditors.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.person_off, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          const Text('No hay auditores senior disponibles.'),
                          const SizedBox(height: 8),
                          Text(
                            'Los auditores senior pueden ser asignados a riesgos críticos y de alta prioridad.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Header con estadísticas generales
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        color: AppColors.primary.withOpacity(0.1),
                        child: Row(
                          children: [
                            Icon(Icons.people, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              '${auditors.length} Auditores Senior',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Disponibles',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Lista de auditores con estadísticas
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: auditors.length,
                        itemBuilder: (context, index) {
                          final auditor = auditors[index];
                          return _buildAuditorCard(context, auditor, riskProvider);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ▼▼▼ MÉTODO PARA CONSTRUIR TARJETA DE AUDITOR CON ESTADÍSTICAS ▼▼▼
  Widget _buildAuditorCard(BuildContext context, UserModel auditor, RiskProvider riskProvider) {
    // ▼▼▼ USAR ESTADÍSTICAS DEL MODELO EN LUGAR DE CALCULAR ▼▼▼
    final totalRisks = auditor.totalRisksAssigned ?? 0;
    final openRisks = auditor.openRisks ?? 0;
    final inProgressRisks = auditor.inProgressRisks ?? 0;
    final completedRisks = auditor.closedRisks ?? 0;
    final pendingReviewRisks = auditor.pendingReviewRisks ?? 0;
    
    // Calcular riesgos críticos (necesitamos obtener los riesgos asignados para esto)
    final assignedRisks = riskProvider.risks.where((risk) => risk.assignedUserId == auditor.id).toList();
    final criticalRisks = assignedRisks.where((risk) => risk.riskLevel == 'Alto' || risk.riskLevel == 'Crítico').length;
    // ▲▲▲ FIN DE ESTADÍSTICAS ACTUALIZADAS ▲▲▲

    // Determinar color de carga de trabajo basado en estadísticas reales
    Color workloadColor;
    String workloadText;
    IconData workloadIcon;
    
    if (totalRisks <= 3) {
      workloadColor = Colors.green;
      workloadText = 'Disponible';
      workloadIcon = Icons.check_circle;
    } else if (totalRisks <= 6) {
      workloadColor = Colors.orange;
      workloadText = 'Ocupado';
      workloadIcon = Icons.schedule;
    } else {
      workloadColor = Colors.red;
      workloadText = 'Sobrecargado';
      workloadIcon = Icons.warning;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: ExpansionTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                auditor.name.isNotEmpty ? auditor.name[0].toUpperCase() : 'A',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            if (assignedRisks.isNotEmpty)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: workloadColor,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '${assignedRisks.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          auditor.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              auditor.email,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(workloadIcon, size: 14, color: workloadColor),
                const SizedBox(width: 4),
                Text(
                  workloadText,
                  style: TextStyle(
                    color: workloadColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${totalRisks} riesgos asignados',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Estadísticas detalladas
                Text(
                  'Estadísticas de Carga de Trabajo',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatChip(
                        'Abiertos',
                        openRisks.toString(),
                        Colors.blue,
                        Icons.folder_open,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatChip(
                        'En Progreso',
                        inProgressRisks.toString(),
                        Colors.orange,
                        Icons.work,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatChip(
                        'Completados',
                        completedRisks.toString(),
                        Colors.green,
                        Icons.check_circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatChip(
                        'Pendientes',
                        pendingReviewRisks.toString(),
                        Colors.purple,
                        Icons.pending,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatChip(
                        'Críticos',
                        criticalRisks.toString(),
                        Colors.red,
                        Icons.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatChip(
                        'Total',
                        totalRisks.toString(),
                        Colors.grey,
                        Icons.assignment,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.assignment_ind, size: 18),
                        label: const Text('Asignar Riesgo'),
                        onPressed: () => _showAssignRiskDialog(context, auditor, riskProvider),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('Ver Tareas'),
                        onPressed: () => _showAuditorTasks(context, auditor, assignedRisks),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ▼▼▼ MÉTODO PARA CONSTRUIR CHIPS DE ESTADÍSTICAS ▼▼▼
  Widget _buildStatChip(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ▼▼▼ MÉTODO PARA MOSTRAR DIÁLOGO DE ASIGNACIÓN DE RIESGO ▼▼▼
  void _showAssignRiskDialog(BuildContext context, UserModel auditor, RiskProvider riskProvider) {
    final unassignedRisks = riskProvider.risks.where((risk) => risk.assignedUserId == null).toList();
    
    if (unassignedRisks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay riesgos sin asignar disponibles')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Asignar Riesgo a ${auditor.name}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: unassignedRisks.length,
              itemBuilder: (context, index) {
                final risk = unassignedRisks[index];
                return ListTile(
                  title: Text(risk.asset),
                  subtitle: Text('Nivel: ${risk.riskLevel} • Estado: ${risk.statusText}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRiskLevelColor(risk.riskLevel).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      risk.riskLevel,
                      style: TextStyle(
                        color: _getRiskLevelColor(risk.riskLevel),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  onTap: () {
                    riskProvider.assignRisk(risk.id, auditor);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Riesgo "${risk.asset}" asignado a ${auditor.name}')),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  // ▼▼▼ MÉTODO PARA MOSTRAR TAREAS DEL AUDITOR ▼▼▼
  void _showAuditorTasks(BuildContext context, UserModel auditor, List<Risk> assignedRisks) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Tareas de ${auditor.name}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: assignedRisks.isEmpty
                ? const Center(child: Text('No tiene riesgos asignados'))
                : ListView.builder(
                    itemCount: assignedRisks.length,
                    itemBuilder: (context, index) {
                      final risk = assignedRisks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(risk.asset),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Nivel: ${risk.riskLevel}'),
                              Text('Estado: ${risk.statusText}'),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(risk.status).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              risk.statusText,
                              style: TextStyle(
                                color: _getStatusColor(risk.status),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  // ▼▼▼ MÉTODOS AUXILIARES PARA COLORES ▼▼▼
  Color _getRiskLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'crítico':
        return Colors.red;
      case 'alto':
        return Colors.orange;
      case 'medio':
        return Colors.yellow[700]!;
      case 'bajo':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(RiskStatus status) {
    switch (status) {
      case RiskStatus.open:
        return Colors.blue;
      case RiskStatus.inProgress:
        return Colors.orange;
      case RiskStatus.closed:
        return Colors.green;
      case RiskStatus.pendingReview:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}