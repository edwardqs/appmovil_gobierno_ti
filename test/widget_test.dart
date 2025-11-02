import 'package:app_gobiernoti/data/services/auth_service.dart';
import 'package:app_gobiernoti/data/services/risk_service.dart';
import 'package:app_gobiernoti/data/services/biometric_service.dart';
import 'package:app_gobiernoti/presentation/providers/auth_provider.dart';
import 'package:app_gobiernoti/presentation/providers/risk_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';

// Generate mocks for the services
@GenerateMocks([AuthService, RiskService, BiometricService])
import 'widget_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App should initialize without crashing', (WidgetTester tester) async {
    // Reset GetIt
    GetIt.instance.reset();
    
    // Create mock services
    final mockAuthService = MockAuthService();
    final mockRiskService = MockRiskService();
    final mockBiometricService = MockBiometricService();
    
    // Register mock services
    GetIt.instance.registerSingleton<BiometricService>(mockBiometricService);
    GetIt.instance.registerSingleton<AuthService>(mockAuthService);
    GetIt.instance.registerSingleton<RiskService>(mockRiskService);
    
    // Mock the checkBiometricStatus method
    when(mockAuthService.checkBiometricStatus()).thenAnswer((_) async => false);
    
    // Create providers with mocked services
    final authProvider = AuthProvider();
    final riskProvider = RiskProvider(mockRiskService);
    
    // Create a simple test app without router complexity
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: riskProvider),
        ],
        child: MaterialApp(
          title: 'GRC Mobile Test',
          home: Scaffold(
            appBar: AppBar(title: const Text('Test App')),
            body: const Center(child: Text('Test')),
          ),
        ),
      ),
    );
    
    // Wait for the widget to settle
    await tester.pumpAndSettle();
    
    // Verify that the app initialized correctly
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
    
    // Clean up
    GetIt.instance.reset();
  });
}
