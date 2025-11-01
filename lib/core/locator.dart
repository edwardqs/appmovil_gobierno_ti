import 'package:get_it/get_it.dart';
import '../data/services/auth_service.dart';
import '../data/services/risk_service.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/risk_provider.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // 1. Registrar Servicios
  locator.registerLazySingleton(() => AuthService());
  locator.registerLazySingleton(() => RiskService());

  // 2. Registrar Providers (que dependen de los servicios)
  // Le decimos a GetIt que para construir un AuthProvider, necesita
  // obtener la instancia de AuthService que ya registramos.
  locator.registerLazySingleton(() => AuthProvider(locator<AuthService>()));
  locator.registerLazySingleton(() => RiskProvider(locator<RiskService>()));
}
