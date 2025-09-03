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

  // Helper para obtener el color basado en el nivel de riesgo.
  Color _getRiskColor(int inherentRisk) {
    if (inherentRisk >= 20) return AppColors.error;
    if (inherentRisk >= 13) return AppColors.warning;
    if (inherentRisk >= 7) return AppColors.info;
    return AppColors.success;
  }

  // Helper para obtener el texto del nivel de riesgo.
  String _getRiskLevel(int inherentRisk) {
    if (inherentRisk >= 20) return 'CRÍTICO';
    if (inherentRisk >= 13) return 'ALTO';
    if (inherentRisk >= 7) return 'MEDIO';
    return 'BAJO';
  }

  // Helper para obtener el texto del estado del riesgo.
  String _getRiskStatusText(RiskStatus status) {
    switch (status) {
      case RiskStatus.open:
        return 'Abierto';
      case RiskStatus.closed:
        return 'Cerrado';
      case RiskStatus.inProgress:
        return 'En Progreso';
      default:
        return '';
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Título del riesgo.
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
                  // Puntuación de riesgo inherente.
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
              // Activo afectado.
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
              // Nivel de riesgo y estado.
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: riskColor.withAlpha((255 * 0.1).round()), // Usar withAlpha en lugar de withOpacity
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
                    riskStatusText, // Usar el helper para obtener el texto del estado
                    style: TextStyle(
                      color: risk.status == RiskStatus.open
                          ? AppColors.info
                          : AppColors.success,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}