import 'package:app_gobiernoti/core/locator.dart';
import 'package:app_gobiernoti/core/router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/risk_provider.dart';

void main() {
  setupLocator();
  runApp(const GRCApp());
}

class GRCApp extends StatelessWidget {
  const GRCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: locator<AuthProvider>()),
        ChangeNotifierProvider.value(value: locator<RiskProvider>()),
      ],
      // 3. Usamos MaterialApp.router y le pasamos nuestra configuración.
      child: MaterialApp.router(
        routerConfig: router,
        title: 'GRC Mobile',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
