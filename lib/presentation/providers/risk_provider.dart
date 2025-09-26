// lib/presentation/providers/risk_provider.dart

import 'package:flutter/foundation.dart';
import '../../data/models/risk_model.dart';
import '../../data/models/user_model.dart';
import '../../data/services/risk_service.dart';

class RiskProvider with ChangeNotifier {
  final RiskService _riskService;

  RiskProvider(this._riskService) {
    fetchRisks();
    fetchAuditors();
  }

  List<Risk> _risks = [];
  List<Risk> get risks => _risks;

  List<UserModel> _auditors = [];
  List<UserModel> get auditors => _auditors;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Future<void> fetchRisks() async {
    _isLoading = true;
    notifyListeners();
    try {
      _risks = await _riskService.getRisks();
    } catch (e) {
      print(e);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAuditors() async {
    try {
      _auditors = await _riskService.getAuditors();
      notifyListeners();
    } catch (e) {
      print(e);
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
    final newRisk = Risk(
      id: _riskService.generateNewId(),
      title: title, asset: asset, status: RiskStatus.open,
      probability: probability, impact: impact,
      controlEffectiveness: controlEffectiveness,
      comment: comment, imagePaths: imagePaths,
    );
    await _riskService.addRisk(newRisk);
    await fetchRisks();
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
}