import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:app_gobiernoti/data/models/risk_model.dart';
import 'package:app_gobiernoti/data/services/risk_service.dart';
import 'package:app_gobiernoti/presentation/providers/risk_provider.dart';

// Genera un archivo mock para RiskService.
@GenerateMocks([RiskService])
import 'risk_provider_test.mocks.dart';

void main() {
  late RiskProvider riskProvider;
  late MockRiskService mockRiskService;

  setUp(() {
    mockRiskService = MockRiskService();

    // Al inicializar el provider, éste llama a fetchRisks y fetchAuditors.
    // Necesitamos configurar el mock para que responda a esas llamadas
    // desde el principio para evitar errores en el setup.
    when(mockRiskService.getRisks()).thenAnswer((_) async => []);
    when(mockRiskService.getAuditors()).thenAnswer((_) async => []);

    riskProvider = RiskProvider(mockRiskService);
  });

  group('RiskProvider', () {
    test('Initial state is correct (isLoading is false after constructor fetches)', () {
      // El constructor es async, pero no lo esperamos aquí.
      // El estado inicial síncrono es isLoading = true.
      // Después de que los fetches en el constructor completan, debería ser false.
      // Lo probamos en el siguiente test de forma más robusta.
      expect(riskProvider.risks, isEmpty);
      expect(riskProvider.auditors, isEmpty);
    });

    test('fetchRisks should get risks from the service', () async {
      // Arrange
      final mockRisks = [
        Risk(
          id: 'R001',
          title: 'Test Risk',
          asset: 'Test Asset',
          status: RiskStatus.open,
          probability: 1, impact: 1, controlEffectiveness: 1,
        )
      ];
      // Sobrescribimos la configuración del setUp para esta prueba específica.
      when(mockRiskService.getRisks()).thenAnswer((_) async => mockRisks);

      // Act
      await riskProvider.fetchRisks();

      // Assert
      expect(riskProvider.risks, mockRisks);
      expect(riskProvider.isLoading, isFalse);
      // Verificamos que el método del servicio fue llamado.
      verify(mockRiskService.getRisks()).called(2);
    });

    test('addRisk should call service and refetch risks', () async {
      // Arrange
      final newRisk = Risk(
        id: 'R002', title: 'New Risk', asset: 'New Asset',
        status: RiskStatus.open, probability: 2, impact: 2, controlEffectiveness: 0.5,
      );

      // Mock para generateNewId
      when(mockRiskService.generateNewId()).thenReturn('R002');
      // Mock para addRisk
      when(mockRiskService.addRisk(any)).thenAnswer((_) async => newRisk);
      // Mock para el fetchRisks que se llama internamente
      when(mockRiskService.getRisks()).thenAnswer((_) async => [newRisk]);

      // Act
      await riskProvider.addRisk('New Risk', 'New Asset', 2, 2, 0.5, null, []);

      // Assert
      // Verificamos que addRisk fue llamado en el servicio.
      verify(mockRiskService.addRisk(any)).called(1);
      // Verificamos que los riesgos se actualizaron después de añadir.
      expect(riskProvider.risks.length, 1);
      expect(riskProvider.risks.first.id, 'R002');
    });

  });
}
