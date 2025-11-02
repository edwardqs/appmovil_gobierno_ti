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

  /// Intenta autenticar al usuario usando biometría.
  Future<bool> authenticate(String reason) async {
    try {
      // Usamos la configuración por defecto, que es segura.
      // Eliminamos la sección 'authMessages' que causaba los errores.
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // true: Solo permite biometría (huella, rostro "fuerte").
          // false: Permite biometría O el PIN/Patrón del dispositivo.
          // Para máxima seguridad (tipo app bancaria), se recomienda 'true'.
          biometricOnly: true,
          stickyAuth: false, // Evita bucles infinitos al no mantener el diálogo activo
        ),
      );
    } on PlatformException catch (e) {
      print('Error durante la autenticación biométrica: $e');
      
      // Manejar códigos de error específicos para evitar bucles
      if (e.code == 'UserCancel' || 
          e.code == 'SystemCancel' || 
          e.code == 'AppCancel') {
        print('Autenticación biométrica cancelada por el usuario');
        return false;
      }
      
      if (e.code == 'BiometricNotAvailable' || 
          e.code == 'BiometricNotEnrolled') {
        print('Biometría no disponible o no configurada');
        return false;
      }
      
      // Para otros errores, también retornar false para evitar bucles
      return false;
    } catch (e) {
      print('Error general en autenticación biométrica: $e');
      return false;
    }
  }
}
