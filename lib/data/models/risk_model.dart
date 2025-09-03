import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// Enum para los estados de un riesgo, facilita el manejo y la legibilidad.
enum RiskStatus {
  open,
  inProgress,
  closed,
}

class Risk {
  final String id;
  final String title;
  final String asset; // Activo afectado
  final RiskStatus status;
  final int probability; // 1-5
  final int impact; // 1-5
  final double controlEffectiveness; // 0.0 - 1.0

  Risk({
    required this.id,
    required this.title,
    required this.asset,
    required this.status,
    required this.probability,
    required this.impact,
    this.controlEffectiveness = 0.5, // Valor por defecto
  });

  // Cálculo del riesgo inherente
  int get inherentRisk => probability * impact;

  // Cálculo del riesgo residual
  double get residualRisk => (probability * (1 - controlEffectiveness)) * impact;

  // Determina el nivel de riesgo basado en el score inherente
  String get riskLevel {
    if (inherentRisk >= 20) return 'Crítico';
    if (inherentRisk >= 13) return 'Alto';
    if (inherentRisk >= 7) return 'Medio';
    return 'Bajo';
  }

// Devuelve un color asociado al nivel de riesgo para la UI
  Color get riskColor {
    switch (riskLevel) {
      case 'Critico':
      // Correcto: criticalRisk
        return AppColors.criticalRisk;
      case 'Alto':
      // Correcto: highRisk
        return AppColors.highRisk;
      case 'Medio':
      // Correcto: mediumRisk
        return AppColors.mediumRisk;
      default:
      // Correcto: lowRisk
        return AppColors.lowRisk;
    }
  }

  // Devuelve un texto formateado para el estado
  String get statusText {
    switch (status) {
      case RiskStatus.open:
        return 'Abierto';
      case RiskStatus.inProgress:
        return 'En Tratamiento';
      case RiskStatus.closed:
        return 'Cerrado';
    }
  }
}

