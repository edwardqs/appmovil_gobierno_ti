import 'package:flutter/foundation.dart';
import '../../data/models/risk_model.dart';
import '../../data/services/risk_service.dart';

class RiskProvider with ChangeNotifier {
  final RiskService _riskService;

  RiskProvider(this._riskService) {
    // Carga los riesgos iniciales cuando se crea el provider.
    fetchRisks();
  }

  // Lista privada de riesgos.
  List<Risk> _risks = [];
  // Getter público para acceder a la lista de riesgos desde la UI.
  List<Risk> get risks => _risks;

  // Estado para manejar si se está cargando la información.
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // Método para obtener los riesgos desde el servicio.
  Future<void> fetchRisks() async {
    _isLoading = true;
    notifyListeners(); // Notifica a la UI que empiece a mostrar el loading.

    try {
      // Llama al servicio para obtener los datos.
      _risks = await _riskService.getRisks();
    } catch (e) {
      // Manejo de errores (en una app real se podría guardar el error).
      print(e);
    }

    _isLoading = false;
    notifyListeners(); // Notifica a la UI que la carga ha terminado.
  }

  // Método para añadir un nuevo riesgo.
  Future<void> addRisk(String title, String asset, int probability, int impact,
      double controlEffectiveness) async {
    // Crea una nueva instancia del riesgo con los datos del formulario.
    final newRisk = Risk(
      id: _riskService.generateNewId(), // Genera un ID simulado.
      title: title,
      asset: asset,
      status: RiskStatus.open, // Los nuevos riesgos siempre empiezan abiertos.
      probability: probability,
      impact: impact,
      controlEffectiveness: controlEffectiveness,
    );

    // Llama al servicio para añadir el riesgo.
    await _riskService.addRisk(newRisk);

    // Notifica a la UI que la lista ha cambiado para que se redibuje.
    notifyListeners();
  }
}

