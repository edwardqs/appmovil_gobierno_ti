import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final SupabaseClient _supabase = Supabase.instance.client;

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
    print('🔐 BiometricService: Iniciando authenticate() con razón: $localizedReason');
    try {
      print('🔐 BiometricService: Llamando a _auth.authenticate()...');
      final result = await _auth.authenticate(
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
      print('🔐 BiometricService: Resultado de autenticación: $result');
      return result;
    } on PlatformException catch (e) {
      print('🔐 BiometricService: Error PlatformException: $e');
      return false;
    } catch (e) {
      print('🔐 BiometricService: Error general: $e');
      return false;
    }
  }

  // Generar hash único del dispositivo
  String _generateDeviceId() {
    final String platformInfo = Platform.isAndroid ? 'android' : 'ios';
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return '$platformInfo-$timestamp';
  }

  // Generar hash biométrico simulado
  String _generateBiometricHash(String userId, String deviceId) {
    final String data = '$userId-$deviceId-${DateTime.now().millisecondsSinceEpoch}';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Obtener ID del dispositivo
  Future<String> getDeviceId() async {
    return _generateDeviceId();
  }

  // Generar hash biométrico
  Future<String> generateBiometricData() async {
    final String deviceId = _generateDeviceId();
    return _generateBiometricHash('temp-user', deviceId);
  }

  // Generar datos biométricos para registro (método legacy)
  Future<Map<String, String>> generateBiometricDataMap() async {
    final String deviceId = _generateDeviceId();
    final String biometricHash = _generateBiometricHash('temp-user', deviceId);
    
    return {
      'device_id': deviceId,
      'biometric_hash': biometricHash,
    };
  }

  // Registrar token biométrico en Supabase
  Future<Map<String, dynamic>?> registerBiometricToken(String userId) async {
    try {
      final String deviceId = _generateDeviceId();
      final String biometricHash = _generateBiometricHash(userId, deviceId);

      final response = await _supabase.rpc('generate_biometric_token', params: {
        'p_device_id': deviceId,
        'p_biometric_hash': biometricHash,
      });

      if (response != null && response['success'] == true) {
        return {
          'success': true,
          'token': response['token'],
          'device_id': deviceId,
          'biometric_hash': biometricHash,
          'expires_at': response['expires_at'],
        };
      }
      return null;
    } catch (e) {
      print('Error registering biometric token: $e');
      return null;
    }
  }

  // Validar token biométrico
  Future<UserModel?> validateBiometricToken(
    String token,
    String deviceId,
    String biometricHash,
  ) async {
    try {
      print('🔍 BiometricService: validateBiometricToken iniciado');
      print('🔍 BiometricService: token: ${token.substring(0, 10)}...');
      print('🔍 BiometricService: deviceId: $deviceId');
      print('🔍 BiometricService: biometricHash: ${biometricHash.substring(0, 10)}...');
      
      final response = await _supabase.rpc('validate_biometric_token', params: {
        'p_token': token,
        'p_device_id': deviceId,
        'p_biometric_hash': biometricHash,
      });

      print('🔍 BiometricService: Respuesta de Supabase: $response');

      if (response != null && response['success'] == true) {
        print('🔍 BiometricService: Token válido, creando UserModel...');
        final userData = response['user'];
        print('🔍 BiometricService: userData: $userData');
        return UserModel(
          id: userData['id'],
          name: userData['name'],
          email: userData['email'],
          role: UserModel.roleFromString(userData['role']),
          biometricEnabled: true,
          biometricToken: token,
          deviceId: deviceId,
        );
      } else {
        print('🔍 BiometricService: Token inválido o respuesta fallida');
        print('🔍 BiometricService: response[success]: ${response?['success']}');
        print('🔍 BiometricService: response[message]: ${response?['message']}');
      }
      return null;
    } catch (e) {
      print('🔍 BiometricService: Error validating biometric token: $e');
      return null;
    }
  }

  // Login completo con biometría
  Future<UserModel?> loginWithBiometrics(
    String token,
    String deviceId,
    String biometricHash,
  ) async {
    print('🔐 BiometricService: loginWithBiometrics iniciado');
    print('🔐 BiometricService: token: ${token.substring(0, 10)}..., deviceId: $deviceId');
    try {
      // Primero autenticar con biometría del dispositivo
      print('🔐 BiometricService: Llamando a authenticate()...');
      final bool isAuthenticated = await authenticate('Autentícate para iniciar sesión');
      print('🔐 BiometricService: ¿Autenticado? $isAuthenticated');

      if (!isAuthenticated) {
        print('🔐 BiometricService: Autenticación falló, retornando null');
        return null;
      }

      // Luego validar el token en Supabase
      print('🔐 BiometricService: Validando token en Supabase...');
      final result = await validateBiometricToken(token, deviceId, biometricHash);
      print('🔐 BiometricService: Resultado de validación: ${result != null ? "Usuario encontrado" : "Usuario no encontrado"}');
      return result;
    } catch (e) {
      print('🔐 BiometricService: Error during biometric login: $e');
      return null;
    }
  }

  // Configurar biometría para un usuario existente
  Future<Map<String, dynamic>?> setupBiometricForUser(UserModel user) async {
    try {
      // Verificar disponibilidad
      if (!await hasBiometrics()) {
        return {
          'success': false,
          'message': 'La autenticación biométrica no está disponible en este dispositivo'
        };
      }

      // Autenticar para configurar
      final bool isAuthenticated = await authenticate('Configura la autenticación biométrica');

      if (!isAuthenticated) {
        return {
          'success': false,
          'message': 'Autenticación biométrica cancelada'
        };
      }

      // Registrar token
      final tokenData = await registerBiometricToken(user.id);
      
      if (tokenData != null && tokenData['success'] == true) {
        return {
          'success': true,
          'message': 'Autenticación biométrica configurada exitosamente',
          'token': tokenData['token'],
          'device_id': tokenData['device_id'],
          'biometric_hash': tokenData['biometric_hash'],
        };
      }

      return {
        'success': false,
        'message': 'Error al configurar la autenticación biométrica'
      };
    } catch (e) {
      print('Error setting up biometric authentication: $e');
      return {
        'success': false,
        'message': 'Error inesperado: $e'
      };
    }
  }
}