import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Script de depuración para verificar el estado de la biometría
// Ejecuta esto después de que el SnackBar diga "Biometría habilitada exitosamente"

Future<void> debugBiometricStatus() async {
  print('🔍 [DEBUG] === ESTADO DE BIOMETRÍA ===');
  
  final secureStorage = FlutterSecureStorage();
  final prefs = await SharedPreferences.getInstance();
  
  // Verificar almacenamiento seguro
  final refreshToken = await secureStorage.read(key: 'biometric_refresh_token');
  final accessToken = await secureStorage.read(key: 'biometric_access_token');
  final deviceId = await secureStorage.read(key: 'biometric_device_id');
  final userEmail = await secureStorage.read(key: 'biometric_user_email');
  
  print('🔍 [DEBUG] Refresh Token: ${refreshToken != null ? "✅ EXISTE" : "❌ NO EXISTE"}');
  print('🔍 [DEBUG] Access Token: ${accessToken != null ? "✅ EXISTE" : "❌ NO EXISTE"}');
  print('🔍 [DEBUG] Device ID: ${deviceId != null ? "✅ EXISTE" : "❌ NO EXISTE"}');
  print('🔍 [DEBUG] User Email: ${userEmail != null ? "✅ EXISTE" : "❌ NO EXISTE"}');
  
  // Verificar SharedPreferences
  final biometricEnabled = prefs.getBool('biometric_enabled');
  print('🔍 [DEBUG] Biometric Enabled (Prefs): ${biometricEnabled != null ? biometricEnabled : "❌ NO EXISTE"}');
  
  // Resumen
  final allCredentialsExist = refreshToken != null && 
                              deviceId != null && 
                              userEmail != null;
  
  print('🔍 [DEBUG] === RESUMEN ===');
  print('🔍 [DEBUG] Credenciales completas: ${allCredentialsExist ? "✅ SÍ" : "❌ NO"}');
  
  if (!allCredentialsExist) {
    print('🔍 [DEBUG] ⚠️  Las credenciales no se guardaron correctamente');
  } else {
    print('🔍 [DEBUG] ✅ Las credenciales se guardaron correctamente');
  }
  
  print('🔍 [DEBUG] === FIN DEBUG ===');
}