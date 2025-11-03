// lib/presentation/providers/risk_provider.dart

import 'package:flutter/foundation.dart';
import '../../data/models/risk_model.dart';
import '../../data/models/user_model.dart';
import '../../data/services/risk_service.dart';

class RiskProvider with ChangeNotifier {
  final RiskService _riskService;

  RiskProvider(this._riskService);

  List<Risk> _risks = [];
  List<Risk> get risks => _risks;

  List<UserModel> _auditors = [];
  List<UserModel> get auditors => _auditors;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _risksInitialized = false;
  bool _auditorsInitialized = false;

  Future<void> fetchRisks() async {
    _isLoading = true;
    notifyListeners();
    try {
      _risks = await _riskService.getRisks();
      _risksInitialized = true;
    } catch (e) {
      print(e);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAuditors() async {
    try {
      _auditors = await _riskService.getAuditors();
      _auditorsInitialized = true;
      notifyListeners();
    } catch (e) {
      print(e);
    }
  }

  /// Inicializa los riesgos solo si no han sido cargados previamente
  Future<void> ensureRisksLoaded() async {
    if (!_risksInitialized) {
      await fetchRisks();
    }
  }

  /// Inicializa los auditores solo si no han sido cargados previamente
  Future<void> ensureAuditorsLoaded() async {
    if (!_auditorsInitialized) {
      await fetchAuditors();
    }
  }

  Future<void> assignRisk(String riskId, UserModel user) async {
    try {
      await _riskService.assignRiskToUser(riskId, user);
      final riskIndex = _risks.indexWhere((r) => r.id == riskId);
      if (riskIndex != -1) {
        _risks[riskIndex].assignedUserId = user.id;
        _risks[riskIndex].assignedUserName = user.name;
        notifyListeners();
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> addRisk(
      String title, String asset, int probability, int impact,
      double controlEffectiveness, String? comment, List<String> imagePaths) async {
    try {
      print('🔄 [RISK_PROVIDER] Iniciando creación de riesgo...');
      print('🔄 [RISK_PROVIDER] Título: $title');
      print('🔄 [RISK_PROVIDER] Asset: $asset');
      print('🔄 [RISK_PROVIDER] Imágenes: ${imagePaths.length}');
      
      final newRisk = Risk(
        id: _riskService.generateNewId(),
        title: title, asset: asset, status: RiskStatus.open,
        probability: probability, impact: impact,
        controlEffectiveness: controlEffectiveness,
        comment: comment, imagePaths: imagePaths,
      );
      
      print('🔄 [RISK_PROVIDER] Riesgo creado localmente con ID: ${newRisk.id}');
      print('🔄 [RISK_PROVIDER] Llamando a RiskService.addRisk...');
      
      await _riskService.addRisk(newRisk);
      
      print('✅ [RISK_PROVIDER] Riesgo guardado en Supabase exitosamente');
      print('🔄 [RISK_PROVIDER] Actualizando lista de riesgos...');
      
      await fetchRisks();
      
      print('✅ [RISK_PROVIDER] Lista de riesgos actualizada');
    } catch (e) {
      print('❌ [RISK_PROVIDER] Error al crear riesgo: $e');
      print('❌ [RISK_PROVIDER] Tipo de error: ${e.runtimeType}');
      print('❌ [RISK_PROVIDER] Stack trace: ${StackTrace.current}');
      rethrow; // Re-lanzar el error para que la UI pueda manejarlo
    }
  }

  // ▼▼▼ MÉTODO PARA GUARDAR Y NOTIFICAR EL ANÁLISIS DE LA IA ▼▼▼
  Future<void> saveAiAnalysis(String riskId, String analysisText) async {
    try {
      await _riskService.saveAiAnalysis(riskId, analysisText);
      final riskIndex = _risks.indexWhere((r) => r.id == riskId);
      if (riskIndex != -1) {
        _risks[riskIndex].aiAnalysis = analysisText;
        notifyListeners();
      }
    } catch (e){
      print(e);
    }
  }
  // ▼▼▼ FIRMA DE FUNCIÓN CORREGIDA ▼▼▼
  Future<void> updateRiskStatus(String riskId, RiskStatus newStatus, {String? reviewNotes}) async {
    try {
      await _riskService.updateRiskStatus(riskId, newStatus, reviewNotes: reviewNotes);
      final riskIndex = _risks.indexWhere((r) => r.id == riskId);
      if (riskIndex != -1) {
        _risks[riskIndex].status = newStatus;
        _risks[riskIndex].reviewNotes = reviewNotes;
        notifyListeners();
      }
    } catch (e) {
      print(e);
    }
  }

  // ▼▼▼ NUEVOS MÉTODOS PARA COMENTARIOS ▼▼▼
  /// Agrega un comentario a un riesgo
  Future<void> addRiskComment(String riskId, String comment, {String type = 'general'}) async {
    try {
      await _riskService.addRiskComment(riskId, comment, type: type);
      // No necesitamos notificar listeners aquí ya que los comentarios se cargan dinámicamente
    } catch (e) {
      print('Error adding risk comment: $e');
      rethrow; // Re-lanzar el error para que la UI pueda manejarlo
    }
  }

  /// Obtiene los comentarios de un riesgo
  Future<List<Map<String, dynamic>>> getRiskComments(String riskId) async {
    try {
      return await _riskService.getRiskComments(riskId);
    } catch (e) {
      print('Error getting risk comments: $e');
      return []; // Retornar lista vacía en caso de error
    }
  }

  // ▼▼▼ NUEVO MÉTODO PARA ELIMINACIÓN DE RIESGOS ▼▼▼
  /// Elimina un riesgo (solo para gerentes)
  Future<void> deleteRisk(String riskId) async {
    try {
      // Eliminar del servicio (base de datos)
      await _riskService.deleteRisk(riskId);
      
      // Eliminar del estado local
      _risks.removeWhere((risk) => risk.id == riskId);
      
      // Notificar a los listeners
      notifyListeners();
    } catch (e) {
      print('Error deleting risk: $e');
      rethrow; // Re-lanzar el error para que la UI pueda manejarlo
    }
  }
}