import 'dart:math';
import '../models/risk_model.dart';

class RiskService {
  // Base de datos en memoria para simular los datos del backend.
  final List<Risk> _risks = [
    Risk(
      id: 'R001',
      title: 'Fuga de datos en servidor de producción',
      asset: 'Servidor DB Principal',
      status: RiskStatus.open,
      probability: 5,
      impact: 5,
      controlEffectiveness: 0.25,
    ),
    Risk(
      id: 'R002',
      title: 'Ataque de Phishing a empleados',
      asset: 'Plataforma de Email',
      status: RiskStatus.inProgress,
      probability: 4,
      impact: 4,
      controlEffectiveness: 0.5,
    ),
    Risk(
      id: 'R003',
      title: 'Caída del servicio de red en Data Center',
      asset: 'Infraestructura de Red',
      status: RiskStatus.closed,
      probability: 2,
      impact: 5,
      controlEffectiveness: 0.9,
    ),
    Risk(
      id: 'R004',
      title: 'Software desactualizado en portátiles',
      asset: 'Equipos de Cómputo',
      status: RiskStatus.inProgress,
      probability: 3,
      impact: 3,
      controlEffectiveness: 0.75,
    ),
    Risk(
      id: 'R005',
      title: 'Acceso físico no autorizado a oficinas',
      asset: 'Instalaciones Físicas',
      status: RiskStatus.open,
      probability: 2,
      impact: 2,
      controlEffectiveness: 0.6,
    ),
  ];

  // Simula la obtención de todos los riesgos desde una API.
  Future<List<Risk>> getRisks() async {
    // Simula un retardo de red.
    await Future.delayed(const Duration(seconds: 1));
    return _risks;
  }

  // Simula la adición de un nuevo riesgo.
  Future<void> addRisk(Risk newRisk) async {
    // Simula un retardo de red.
    await Future.delayed(const Duration(milliseconds: 500));
    // En una app real, aquí se recibiría el riesgo creado desde la API.
    // Para la simulación, lo añadimos a nuestra lista local.
    _risks.add(newRisk);
  }

  // Genera un ID único para un nuevo riesgo (simulación).
  String generateNewId() {
    return 'R${Random().nextInt(900) + 100}';
  }
}

