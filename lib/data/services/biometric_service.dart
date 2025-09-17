import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> hasBiometrics() async {
    try {
      // Esta comprobación a veces falla en algunos dispositivos,
      // por eso confiaremos más en la lista de sensores disponibles.
      return await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    }
  }

  Future<bool> authenticate(String localizedReason) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          // ▼▼▼ CAMBIO CLAVE AQUÍ ▼▼▼
          // Poner 'biometricOnly' en 'false' permite que el sistema operativo
          // ofrezca otros métodos de desbloqueo si el biométrico "fuerte" no está disponible.
          // En muchos dispositivos, esto activa el desbloqueo facial "de conveniencia".
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
        // ▲▲▲ FIN DEL CAMBIO ▲▲▲
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Autenticación Requerida',
            cancelButton: 'Cancelar',
            biometricHint: '',
          ),
        ],
      );
    } on PlatformException {
      return false;
    }
  }
}