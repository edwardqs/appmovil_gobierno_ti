import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/risk_model.dart';

class RiskListItem extends StatelessWidget {
  final Risk risk;
  final VoidCallback? onTap;

  const RiskListItem({
    super.key,
    required this.risk,
    this.onTap,
  });

  // ... (los métodos _getRiskColor, _getRiskLevel, _getRiskStatusText se mantienen igual)
  Color _getRiskColor(int inherentRisk) {
    if (inherentRisk >= 20) return AppColors.error;
    if (inherentRisk >= 13) return AppColors.warning;
    if (inherentRisk >= 7) return AppColors.info;
    return AppColors.success;
  }

  String _getRiskLevel(int inherentRisk) {
    if (inherentRisk >= 20) return 'CRÍTICO';
    if (inherentRisk >= 13) return 'ALTO';
    if (inherentRisk >= 7) return 'MEDIO';
    return 'BAJO';
  }

  String _getRiskStatusText(RiskStatus status) {
    switch (status) {
      case RiskStatus.open:
        return 'Abierto';
      case RiskStatus.closed:
        return 'Cerrado';
      case RiskStatus.inProgress:
        return 'En Progreso';
      case RiskStatus.pendingReview:
        return 'Pendiente de Revisión';
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = _getRiskColor(risk.inherentRisk);
    final riskLevel = _getRiskLevel(risk.inherentRisk);
    final riskStatusText = _getRiskStatusText(risk.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ... (La sección del título y el activo se mantiene igual)
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
                  Text(
                    risk.inherentRisk.toString(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: riskColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.computer, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    risk.asset,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: riskColor.withAlpha((255 * 0.1).round()),
                      borderRadius: BorderRadius.circular(20),
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
                  const Spacer(),
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

              // ▼▼▼ SECCIÓN DE ASIGNACIÓN AÑADIDA ▼▼▼
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
    );
  }
}