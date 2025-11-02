import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/services/auth_service.dart';
import '../data/services/risk_service.dart';
import '../data/services/biometric_service.dart';
import '../presentation/providers/auth_provider.dart';
import '../presentation/providers/risk_provider.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // ✅ 1. REGISTRAR SERVICIOS (orden correcto)

  // BiometricService (sin dependencias)
  locator.registerLazySingleton(() => BiometricService());

  // ✅ AuthService con SupabaseClient inyectado
  locator.registerLazySingleton(() => AuthService(Supabase.instance.client));

  // ✅ RiskService con SupabaseClient inyectado (opcional)
  locator.registerLazySingleton(() => RiskService(Supabase.instance.client));

  // ✅ 2. REGISTRAR PROVIDERS (después de los servicios)
  locator.registerLazySingleton(() => AuthProvider());
  locator.registerLazySingleton(() => RiskProvider(locator<RiskService>()));
}
