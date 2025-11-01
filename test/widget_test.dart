import 'package:app_gobiernoti/core/locator.dart';
import 'package:app_gobiernoti/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App should initialize without crashing', (WidgetTester tester) async {
    setupLocator();
    
    // Usar runAsync para manejar timers pendientes
    await tester.runAsync(() async {
      await tester.pumpWidget(const GRCApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));
      
      // Verificar que la aplicación se inicia correctamente
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
