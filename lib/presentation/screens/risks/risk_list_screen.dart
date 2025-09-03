import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/risk_model.dart';
import '../dashboard/dashboard_screen.dart'; // Added for RiskStatusFilter

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
        return 'Desconocido';
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
            ],
          ),
        ),
      ),
    );
  }
}

// Nueva clase RiskListScreen
class RiskListScreen extends StatelessWidget {
  final RiskStatusFilter filter;

  const RiskListScreen({super.key, this.filter = RiskStatusFilter.all});

  @override
  Widget build(BuildContext context) {
    // Aquí deberías obtener la lista de riesgos del RiskProvider
    // y filtrarla según el 'filter'
    // Por ahora, es un placeholder:
    final List<Risk> risks = []; // Reemplazar con datos reales del provider

    String screenTitle = 'Todos los Riesgos';
    if (filter == RiskStatusFilter.critical) {
      screenTitle = 'Riesgos Críticos';
    } else if (filter == RiskStatusFilter.high) {
      screenTitle = 'Riesgos Altos';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle),
      ),
      body: ListView.builder(
        itemCount: risks.length, // Usar la lista de riesgos filtrada
        itemBuilder: (context, index) {
          final risk = risks[index];
          // Asumiendo que RiskListItem es el widget que quieres usar para cada item
          return RiskListItem(
            risk: risk,
            onTap: () {
              // Navegar a la pantalla de detalle del riesgo, por ejemplo
              // Navigator.of(context).push(MaterialPageRoute(builder: (_) => RiskDetailScreen(risk: risk)));
            },
          );
        },
      ),
    );
  }
}