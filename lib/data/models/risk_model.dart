// lib/data/models/risk_model.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// Se añadió el nuevo estado "pendingReview"
enum RiskStatus {
  open,
  inProgress,
  pendingReview, // <-- AÑADIDO
  closed,
}

class Risk {
  final String id;
  final String title;
  final String asset;
  RiskStatus status; // Quitamos 'final' para que pueda ser modificado
  final int probability;
  final int impact;
  final double controlEffectiveness;
  final String? comment;
  final List<String> imagePaths;
  String? assignedUserId;
  String? assignedUserName;
  String? reviewNotes;
  String? aiAnalysis;

  Risk({
    required this.id,
    required this.title,
    required this.asset,
    required this.status,
    required this.probability,
    required this.impact,
    this.controlEffectiveness = 0.5,
    this.comment,
    this.imagePaths = const [],
    this.assignedUserId,
    this.assignedUserName,
    this.reviewNotes,
    this.aiAnalysis,
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

  // Se actualizó para dar el texto correspondiente al nuevo estado
  String get statusText {
    switch (status) {
      case RiskStatus.open:
        return 'Abierto';
      case RiskStatus.inProgress:
        return 'En Tratamiento';
      case RiskStatus.pendingReview:
        return 'Pendiente de Revisión'; // <-- AÑADIDO
      case RiskStatus.closed:
        return 'Cerrado';
    }
  }

  // Métodos para serialización JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'asset': asset,
      'status': status.name,
      'probability': probability,
      'impact': impact,
      'control_effectiveness': controlEffectiveness,
      'comment': comment,
      'image_paths': imagePaths,
      'assigned_user_id': assignedUserId,
      'assigned_user_name': assignedUserName,
      'review_notes': reviewNotes,
      'ai_analysis': aiAnalysis,
    };
  }

  factory Risk.fromJson(Map<String, dynamic> json) {
    return Risk(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      asset: json['asset'] ?? '',
      status: _statusFromString(json['status'] ?? 'open'),
      probability: json['probability'] ?? 1,
      impact: json['impact'] ?? 1,
      controlEffectiveness: (json['control_effectiveness'] ?? 0.5).toDouble(),
      comment: json['comment'],
      imagePaths: json['image_paths'] != null 
          ? List<String>.from(json['image_paths']) 
          : [],
      assignedUserId: json['assigned_user_id'],
      assignedUserName: json['assigned_user_name'],
      reviewNotes: json['review_notes'],
      aiAnalysis: json['ai_analysis'],
    );
  }

  static RiskStatus _statusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return RiskStatus.open;
      case 'inprogress':
      case 'in_progress':
        return RiskStatus.inProgress;
      case 'pendingreview':
      case 'pending_review':
        return RiskStatus.pendingReview;
      case 'closed':
        return RiskStatus.closed;
      default:
        return RiskStatus.open;
    }
  }
}