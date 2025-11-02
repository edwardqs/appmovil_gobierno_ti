import 'package:get_it/get_it.dart';
import '../data/services/auth_service.dart';
import '../data/services/risk_service.dart';
import '../data/services/biometric_service.dart'; // <-- 1. IMPORTAR
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/risk_provider.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // 1. Registrar Servicios
  locator.registerLazySingleton(
    () => BiometricService(),
  ); // <-- 2. REGISTRAR PRIMERO
  locator.registerLazySingleton(() => AuthService());
  locator.registerLazySingleton(() => RiskService());

  // 2. Registrar Providers
  locator.registerLazySingleton(
    () => AuthProvider(),
  ); // Ya no necesita AuthService en el constructor
  locator.registerLazySingleton(() => RiskProvider(locator<RiskService>()));
}
