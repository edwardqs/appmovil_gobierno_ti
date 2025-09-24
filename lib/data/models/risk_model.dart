import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum RiskStatus {
  open,
  inProgress,
  closed,
}

class Risk {
  final String id;
  final String title;
  final String asset;
  final RiskStatus status;
  final int probability;
  final int impact;
  final double controlEffectiveness;
  final String? comment; // <-- AÑADIDO
  final List<String> imagePaths; // <-- AÑADIDO

  Risk({
    required this.id,
    required this.title,
    required this.asset,
    required this.status,
    required this.probability,
    required this.impact,
    this.controlEffectiveness = 0.5,
    this.comment, // <-- AÑADIDO
    this.imagePaths = const [], // <-- AÑADIDO
  });

  int get inherentRisk => probability * impact;

  double get residualRisk => (probability * (1 - controlEffectiveness)) * impact;

  String get riskLevel {
    if (inherentRisk >= 20) return 'Crítico';
    if (inherentRisk >= 13) return 'Alto';
    if (inherentRisk >= 7) return 'Medio';
    return 'Bajo';
  }

  Color get riskColor {
    switch (riskLevel) {
      case 'Crítico':
        return AppColors.criticalRisk;
      case 'Alto':
        return AppColors.highRisk;
      case 'Medio':
        return AppColors.mediumRisk;
      default:
        return AppColors.lowRisk;
    }
  }

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