// lib/presentation/widgets/common/risk_list_item.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/risk_model.dart';
import '../../../data/models/user_model.dart';

class RiskListItem extends StatelessWidget {
  final Risk risk;
  final VoidCallback onTap;
  final UserModel? currentUser;
  final Function(String)? onDelete;

  const RiskListItem({
    super.key,
    required this.risk,
    required this.onTap,
    this.currentUser,
    this.onDelete,
  });

  Color _getRiskColor(int inherentRisk) {
    if (inherentRisk >= 20) return AppColors.error;
    if (inherentRisk >= 15) return AppColors.warning;
    if (inherentRisk >= 10) return AppColors.info;
    return AppColors.success;
  }

  String _getRiskLevel(int inherentRisk) {
    if (inherentRisk >= 20) return 'Crítico';
    if (inherentRisk >= 15) return 'Alto';
    if (inherentRisk >= 10) return 'Medio';
    return 'Bajo';
  }

  String _getRiskStatusText(RiskStatus status) {
    switch (status) {
      case RiskStatus.open:
        return 'Abierto';
      case RiskStatus.inProgress:
        return 'En Progreso';
      case RiskStatus.closed:
        return 'Cerrado';
      case RiskStatus.pendingReview:
        return 'Pendiente de Revisión';
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = _getRiskColor(risk.inherentRisk);
    final riskLevel = _getRiskLevel(risk.inherentRisk);
    final riskStatusText = _getRiskStatusText(risk.status);

    // Verificar si el usuario es gerente (puede eliminar cualquier riesgo)
    final isManager = currentUser?.role == UserRole.gerenteAuditoria;
    final canDelete = isManager && onDelete != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          risk.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontSize: 18),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(right: canDelete ? 40 : 0),
                        child: Text(
                          risk.inherentRisk.toString(),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: riskColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.computer, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          risk.asset,
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: riskColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: riskColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          riskLevel,
                          style: TextStyle(
                            color: riskColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        riskStatusText,
                        style: TextStyle(
                          color: risk.status == RiskStatus.open
                              ? AppColors.info
                              : AppColors.success,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  if (risk.assignedUserName != null) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.person_pin_circle_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Asignado a: ',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          risk.assignedUserName!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Icono de eliminación para gerentes (todos los riesgos)
           if (canDelete)
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onDelete!(risk.id),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}