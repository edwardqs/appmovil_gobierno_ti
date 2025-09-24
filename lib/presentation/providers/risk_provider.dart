import 'package:flutter/foundation.dart';
import '../../data/models/risk_model.dart';
import '../../data/services/risk_service.dart';

class RiskProvider with ChangeNotifier {
  final RiskService _riskService;

  RiskProvider(this._riskService) {
    fetchRisks();
  }

  List<Risk> _risks = [];
  List<Risk> get risks => _risks;

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

  // ▼▼▼ MÉTODO CORREGIDO AQUÍ ▼▼▼
  Future<void> addRisk(
      String title,
      String asset,
      int probability,
      int impact,
      double controlEffectiveness,
      String? comment, // Parámetro añadido
      List<String> imagePaths, // Parámetro añadido
      ) async {
    final newRisk = Risk(
      id: _riskService.generateNewId(),
      title: title,
      asset: asset,
      status: RiskStatus.open,
      probability: probability,
      impact: impact,
      controlEffectiveness: controlEffectiveness,
      comment: comment, // Dato añadido
      imagePaths: imagePaths, // Dato añadido
    );

    await _riskService.addRisk(newRisk);

    // Vuelve a cargar los riesgos para incluir el nuevo
    await fetchRisks();
  }
}