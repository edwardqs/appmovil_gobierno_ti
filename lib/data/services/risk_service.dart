// lib/data/services/risk_service.dart

import 'dart:math';
import '../models/risk_model.dart';
import '../models/user_model.dart';

class RiskService {
  final List<Risk> _risks = [
    Risk(
      id: 'R001',
      title: 'Fuga de datos en servidor de producción',
      asset: 'Servidor DB Principal',
      status: RiskStatus.open,
      probability: 5,
      impact: 5,
      controlEffectiveness: 0.25,
      assignedUserId: '1',
      assignedUserName: 'Ana Torres',
      aiAnalysis: null,
    ),
    Risk(
      id: 'R002',
      title: 'Ataque de Phishing a empleados',
      asset: 'Plataforma de Email',
      status: RiskStatus.inProgress,
      probability: 4,
      impact: 4,
      controlEffectiveness: 0.5,
      aiAnalysis: null,
    ),
    Risk(
      id: 'R003',
      title: 'Caída del servicio de red en Data Center',
      asset: 'Infraestructura de Red',
      status: RiskStatus.closed,
      probability: 2,
      impact: 5,
      controlEffectiveness: 0.9,
      aiAnalysis: null,
    ),
    Risk(
      id: 'R004',
      title: 'Software desactualizado en portátiles',
      asset: 'Equipos de Cómputo',
      status: RiskStatus.inProgress,
      probability: 3,
      impact: 3,
      controlEffectiveness: 0.75,
      assignedUserId: '3',
      assignedUserName: 'Luis Gomez',
      aiAnalysis: null,
    ),
    Risk(
      id: 'R005',
      title: 'Acceso físico no autorizado a oficinas',
      asset: 'Instalaciones Físicas',
      status: RiskStatus.open,
      probability: 2,
      impact: 2,
      controlEffectiveness: 0.6,
      aiAnalysis: null,
    ),
  ];
  Future<void> saveAiAnalysis(String riskId, String analysisText) async {
    await Future.delayed(const Duration(milliseconds: 400));
    try{
      final risk = _risks.firstWhere((r) => r.id == riskId);
      risk.aiAnalysis = analysisText;
    } catch (e){
      print("Error: Riesgo no encontrado para guardar el análisis IA.");
    }
  }
  Future<List<Risk>> getRisks() async {
    await Future.delayed(const Duration(seconds: 1));
    return _risks;
  }

  Future<void> addRisk(Risk newRisk) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _risks.add(newRisk);
  }

  String generateNewId() {
    return 'R${Random().nextInt(900) + 100}';
  }

  Future<List<UserModel>> getAuditors() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      UserModel(id: '1', name: 'Ana Torres', email: 'ana.t@company.com', role: UserRole.auditorJunior),
      UserModel(id: '3', name: 'Luis Gomez', email: 'luis.g@company.com', role: UserRole.auditorSenior),
      UserModel(id: '4', name: 'Maria Paz', email: 'maria.p@company.com', role: UserRole.auditorSenior),
    ];
  }

  Future<void> assignRiskToUser(String riskId, UserModel user) async {
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      final risk = _risks.firstWhere((r) => r.id == riskId);
      risk.assignedUserId = user.id;
      risk.assignedUserName = user.name;
    } catch (e) {
      print('Error: Riesgo no encontrado para asignar.');
    }
  }

  // ▼▼▼ FIRMA DE FUNCIÓN CORREGIDA ▼▼▼
  Future<void> updateRiskStatus(String riskId, RiskStatus newStatus, {String? reviewNotes}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    try {
      final risk = _risks.firstWhere((r) => r.id == riskId);
      risk.status = newStatus;
      risk.reviewNotes = reviewNotes;
    } catch (e) {
      print('Error: Riesgo no encontrado para actualizar estado.');
    }
  }
}