import 'package:flutter/material.dart';

// Este archivo ahora importa 'material.dart' y define todos los colores necesarios.
class AppColors {
  // Paleta Principal
  static const Color primary = Color(0xFF0D47A1); // Azul oscuro corporativo
  static const Color accent = Color(0xFF4CAF50); // Verde para acciones positivas
  static const Color background = Color(0xFFF4F6F8);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);

  // Colores Semánticos para Riesgos y Estados
  static const Color criticalRisk = Color(0xFFD32F2F); // Rojo Fuerte
  static const Color highRisk = Color(0xFFF57C00); // Naranja
  static const Color mediumRisk = Color(0xFFFFC107); // Amarillo
  static const Color lowRisk = Color(0xFF4CAF50); // Verde

  // Nombres genéricos para otros usos (reemplazan error, warning, etc.)
  static const Color error = criticalRisk;
  static const Color warning = highRisk;
  static const Color info = primary;
  static const Color success = lowRisk;
}

