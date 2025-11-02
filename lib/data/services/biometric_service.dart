import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
// Eliminamos las importaciones de local_auth_android y local_auth_ios

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Verifica si el dispositivo tiene capacidades biométricas.
  Future<bool> hasBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException catch (e) {
      print('Error al verificar biometría: $e');
      return false;
    }
  }

  /// Autentica al usuario usando biometría.
  Future<bool> authenticate(String reason) async {
    print('🔐 [BIOMETRIC_SERVICE] Iniciando autenticación biométrica...');
    print('🔐 [BIOMETRIC_SERVICE] Razón: $reason');
    
    try {
      // Verificar disponibilidad antes de intentar autenticar
      final isAvailable = await hasBiometrics();
      if (!isAvailable) {
        print('❌ [BIOMETRIC_SERVICE] Biometría no disponible en el dispositivo');
        return false;
      }
      
      print('✅ [BIOMETRIC_SERVICE] Biometría disponible, iniciando autenticación...');
      
      // Usamos la configuración por defecto, que es segura.
      // Eliminamos la sección 'authMessages' que causaba los errores.
      final result = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // true: Solo permite biometría (huella, rostro "fuerte").
          // false: Permite biometría O el PIN/Patrón del dispositivo.
          // Para máxima seguridad (tipo app bancaria), se recomienda 'true'.
          biometricOnly: true,
          stickyAuth: false, // Evita bucles infinitos al no mantener el diálogo activo
        ),
      );
      
      print('🔐 [BIOMETRIC_SERVICE] Resultado de autenticación: $result');
      return result;
    } on PlatformException catch (e) {
      print('❌ [BIOMETRIC_SERVICE] PlatformException: ${e.code} - ${e.message}');
      print('❌ [BIOMETRIC_SERVICE] Detalles completos: $e');
      
      // Manejar códigos de error específicos para evitar bucles
      if (e.code == 'UserCancel' || 
          e.code == 'SystemCancel' || 
          e.code == 'AppCancel') {
        print('🚫 [BIOMETRIC_SERVICE] Autenticación biométrica cancelada por el usuario');
        return false;
      }
      
      if (e.code == 'BiometricNotAvailable' || 
          e.code == 'BiometricNotEnrolled') {
        print('🚫 [BIOMETRIC_SERVICE] Biometría no disponible o no configurada');
        return false;
      }
      
      if (e.code == 'AuthenticationFailed') {
        print('🚫 [BIOMETRIC_SERVICE] Fallo en la autenticación biométrica');
        return false;
      }
      
      if (e.code == 'TooManyAttempts') {
        print('🚫 [BIOMETRIC_SERVICE] Demasiados intentos fallidos');
        return false;
      }
      
      // Para otros errores, también retornar false para evitar bucles
      print('🚫 [BIOMETRIC_SERVICE] Error no manejado específicamente, retornando false');
      return false;
    } catch (e) {
      print('❌ [BIOMETRIC_SERVICE] Error general en autenticación biométrica: $e');
      return false;
    }
  }
}
