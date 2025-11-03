// lib/data/services/auth_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:math'; // Para generar el token aleatorio
import '../models/user_model.dart';
import 'biometric_service.dart';
import 'device_service.dart';
import '../../core/locator.dart';

// ============================================================================
// EXCEPCIONES PERSONALIZADAS
// ============================================================================

class AuthServiceException implements Exception {
  final String code;
  final String message;

  AuthServiceException(this.code, this.message);

  @override
  String toString() => 'AuthServiceException: [$code] $message';
}

class UserProfileException implements Exception {
  final String code;
  final String message;

  UserProfileException(this.code, this.message);

  @override
  String toString() => 'UserProfileException: [$code] $message';
}

class BiometricAuthException implements Exception {
  final String code;
  final String message;

  BiometricAuthException(this.code, this.message);

  @override
  String toString() => 'BiometricAuthException: [$code] $message';
}

// ============================================================================
// AUTH SERVICE
// ============================================================================

class AuthService {
  final SupabaseClient _supabase;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late final BiometricService _biometricService;
  late final DeviceService _deviceService;

  // Claves para almacenamiento
  static const String _keyBiometricToken = 'custom_biometric_token';
  static const String _keyUserEmail = 'biometric_user_email';
  static const String _keyDeviceId = 'biometric_device_id';
  static const String _keyBiometricEnabled = 'biometric_enabled';

  AuthService(this._supabase) {
    _biometricService = locator<BiometricService>();
    _deviceService = locator<DeviceService>();
  }

  // ==========================================================================
  // MÉTODOS DE AUTENTICACIÓN BÁSICA
  // ==========================================================================

  Future<UserModel?> getCurrentUser() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return null;

      final response = await _supabase
          .from('users')
          .select()
          .eq('id', currentUser.id)
          .single();

      return UserModel(
        id: currentUser.id,
        name: response['name'],
        email: response['email'],
        role: UserModel.roleFromString(response['role']),
        biometricEnabled: response['biometric_enabled'] ?? false,
        biometricToken: response['biometric_token'],
        deviceId: response['device_id'],
        dni: response['dni'],
        phone: response['phone'],
        address: response['address'],
      );
    } catch (e) {
      print('❌ Error al obtener usuario actual: $e');
      return null;
    }
  }

  Future<UserModel> login(String email, String password) async {
    try {
      print('🔐 [LOGIN_EMAIL] Iniciando login con email...');

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw AuthServiceException('LOGIN_FAILED', 'No se pudo iniciar sesión');
      }

      print('✅ [LOGIN_EMAIL] Login exitoso, obteniendo perfil...');

      final userData = await _supabase
          .from('users')
          .select()
          .eq('id', response.user!.id)
          .single();

      final user = UserModel(
        id: response.user!.id,
        name: userData['name'],
        email: userData['email'],
        role: UserModel.roleFromString(userData['role']),
        biometricEnabled: userData['biometric_enabled'] ?? false,
        biometricToken: userData['biometric_token'],
        deviceId: userData['device_id'],
        dni: userData['dni'],
        phone: userData['phone'],
        address: userData['address'],
      );

      print(
        '👤 [LOGIN_EMAIL] Perfil obtenido. Biometría habilitada: ${user.biometricEnabled}',
      );

      if (user.biometricEnabled && response.session != null) {
        print('🔄 [LOGIN_EMAIL] Usuario tiene biometría habilitada (Opción B).');

        final deviceId = await _getDeviceId();
        try {
          final isRegistered = await _deviceService.isDeviceRegistered(
            user.id,
            deviceId,
          );
          if (!isRegistered) {
            print('📱 [LOGIN_EMAIL] Dispositivo no registrado, registrando...');
            await _deviceService.registerCurrentDevice(user.id);
            print('✅ [LOGIN_EMAIL] Dispositivo registrado en user_devices');
          } else {
            print('✅ [LOGIN_EMAIL] Dispositivo ya está registrado');
            await _deviceService.updateDeviceLastUsed(user.id, deviceId);
          }
        } catch (e) {
          print('⚠️ [LOGIN_EMAIL] Error al verificar/registrar dispositivo: $e');
        }
      }

      return user;
    } on AuthException catch (e) {
      print('❌ [LOGIN_EMAIL] Error AuthException: ${e.message}');
      throw AuthServiceException('AUTH_ERROR', e.message);
    } catch (e) {
      print('❌ [LOGIN_EMAIL] Error general: $e');
      throw AuthServiceException('UNKNOWN_ERROR', e.toString());
    }
  }

  Future<void> logout() async {
    try {
      print('🔐 [LOGOUT] Cerrando sesión...');

      final hasBiometric = await checkBiometricStatus();

      if (hasBiometric) {
        print('🔐 [LOGOUT] Usuario tiene biometría (Opción B) habilitada');
        print('🔐 [LOGOUT] Limpiando sesión local SIN invalidar tokens en servidor');

        try {
          await _supabase.auth.signOut(scope: SignOutScope.local);
        } catch (e) {
          print('⚠️ [LOGOUT] Error en signOut local (continuando): $e');
        }

        print('✅ [LOGOUT] Sesión local limpiada');
      } else {
        print('🔐 [LOGOUT] Usuario sin biometría, logout normal');
        await _supabase.auth.signOut();
        print('✅ [LOGOUT] Sesión cerrada completamente');
      }
    } catch (e) {
      print('❌ [LOGOUT] Error al cerrar sesión: $e');
    }
  }

  Future<UserModel> registerUser({
    required String email,
    required String password,
    required String name,
    required String role,
    String? dni,
    String? phone,
    String? address,
  }) async {
    try {
      print('📝 [REGISTER] Iniciando registro de usuario...');

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw AuthServiceException(
          'USER_CREATION_FAILED',
          'No se pudo crear el usuario en el sistema de autenticación.',
        );
      }

      print('✅ [REGISTER] Usuario creado en auth.users con ID: ${user.id}');

      try {
        // Insertar directamente en la tabla users
        await _supabase.from('users').insert({
          'id': user.id,
          'name': name,
          'email': email,
          'role': role,
          'dni': dni,
          'phone': phone,
          'address': address,
          'biometric_enabled': false,
        });

        print('✅ [REGISTER] Perfil creado exitosamente en tabla users');

        return UserModel(
          id: user.id,
          name: name,
          email: email,
          role: UserModel.roleFromString(role),
          biometricEnabled: false,
          dni: dni,
          phone: phone,
          address: address,
        );
      } catch (e) {
        print('❌ [REGISTER] Error al crear perfil: $e');
        try {
          await _supabase.auth.signOut(scope: SignOutScope.local);
        } catch (_) {}
        if (e is UserProfileException) rethrow;
        throw UserProfileException(
          'PROFILE_CREATION_FAILED',
          'Error al crear el perfil de usuario: ${e.toString()}',
        );
      }
    } on AuthException catch (e) {
      print('❌ [REGISTER] Error AuthException: ${e.message}');

      String userMessage;
      switch (e.message) {
        case 'User already registered':
          userMessage = 'Este correo electrónico ya está registrado';
          break;
        case 'Password should be at least 6 characters':
          userMessage = 'La contraseña debe tener al menos 6 caracteres';
          break;
        case 'Invalid email':
          userMessage = 'El correo electrónico no es válido';
          break;
        default:
          userMessage = 'Error de registro: ${e.message}';
      }
      throw AuthServiceException('AUTH_ERROR', userMessage);
    } catch (e) {
      print('❌ [REGISTER] Error general: $e');
      if (e is AuthServiceException || e is UserProfileException) {
        rethrow;
      }
      throw AuthServiceException(
        'UNKNOWN_ERROR',
        'Error desconocido durante el registro: ${e.toString()}',
      );
    }
  }

  // ==========================================================================
  // MÉTODOS DE AUTENTICACIÓN BIOMÉTRICA (OPCIÓN B - NUEVA LÓGICA)
  // ==========================================================================

  Future<UserModel?> loginWithBiometrics() async {
    try {
      print('🔐 [LOGIN_BIOMETRIC_B] Iniciando login biométrico (Opción B)...');

      final authenticated = await _biometricService.authenticate(
        'Autentícate para acceder a la aplicación',
      );

      if (!authenticated) {
        print(
          '❌ [LOGIN_BIOMETRIC_B] Autenticación biométrica fallida o cancelada',
        );
        throw BiometricAuthException(
          'AUTH_FAILED',
          'Autenticación biométrica fallida o cancelada',
        );
      }

      print('✅ [LOGIN_BIOMETRIC_B] Autenticación biométrica exitosa');

      final biometricToken = await _secureStorage.read(key: _keyBiometricToken);
      final deviceId = await _secureStorage.read(key: _keyDeviceId);
      final userEmail = await _secureStorage.read(key: _keyUserEmail);

      if (biometricToken == null || deviceId == null) {
        print('❌ [LOGIN_BIOMETRIC_B] Credenciales personalizadas no encontradas');
        await _clearBiometricData();
        throw BiometricAuthException(
          'CREDENTIALS_NOT_FOUND',
          'Credenciales biométricas no encontradas. Inicia sesión manualmente.',
        );
      }

      print('📱 [LOGIN_BIOMETRIC_B] Credenciales encontradas para: $userEmail');
      print('🔄 [LOGIN_BIOMETRIC_B] Llamando a Edge Function "dynamic-responder"...');

      try {
        final response = await _supabase.functions.invoke(
          'dynamic-responder', // El nombre de tu Edge Function
          body: {
            'token': biometricToken,
            'deviceId': deviceId,
          },
        );

        if (response.data == null || response.data['session'] == null) {
          print('❌ [LOGIN_BIOMETRIC_B] La Edge Function no devolvió una sesión');
          throw BiometricAuthException(
            'SESSION_ERROR',
            'Error del servidor de biometría. Inicia sesión manualmente.',
          );
        }

        final sessionData = response.data['session'];

        final session = Session.fromJson(sessionData as Map<String, dynamic>);

        if (session == null) {
          print('❌ [LOGIN_BIOMETRIC_B] JSON de sesión inválido');
          throw BiometricAuthException(
            'SESSION_ERROR',
            'Respuesta de sesión inválida del servidor.',
          );
        }

        if (session.refreshToken == null) {
          print('❌ [LOGIN_BIOMETRIC_B] La sesión no tiene refresh token');
          throw BiometricAuthException(
            'SESSION_ERROR',
            'Sesión incompleta del servidor.',
          );
        }

        await _supabase.auth.setSession(session.refreshToken!);

        print('✅ [LOGIN_BIOMETRIC_B] Sesión restaurada exitosamente desde Edge Function');

        try {
          await _supabase
              .from('biometric_sessions')
              .update({
            'last_used_at': DateTime.now().toUtc().toIso8601String(),
          })
              .eq('user_id', session.user.id)
              .eq('device_id', deviceId)
              .eq('is_active', true);
          print('✅ [LOGIN_BIOMETRIC_B] last_used_at actualizado en biometric_sessions');
        } catch (e) {
          print('⚠️ [LOGIN_BIOMETRIC_B] Error al actualizar last_used_at: $e');
        }

        final userData = await _supabase
            .from('users')
            .select()
            .eq('id', session.user.id)
            .single();

        final user = UserModel(
          id: session.user.id,
          name: userData['name'],
          email: userData['email'],
          role: UserModel.roleFromString(userData['role']),
          biometricEnabled: true,
          biometricToken: userData['biometric_token'],
          deviceId: deviceId,
          dni: userData['dni'],
          phone: userData['phone'],
          address: userData['address'],
        );

        print(
          '✅ [LOGIN_BIOMETRIC_B] Login biométrico completado para: ${user.email}',
        );
        return user;

      } catch (e) {
        print('❌ [LOGIN_BIOMETRIC_B] Error al llamar a Edge Function: $e');
        if (e is FunctionException) {
          // ✅ ¡¡TERCERA CORRECCIÓN!! Usamos e.details
          print('❌ [LOGIN_BIOMETRIC_B] FunctionException: ${e.details}');
          throw BiometricAuthException(
            'SERVER_ERROR',
            // ✅ ¡¡TERCERA CORRECCIÓN!! Usamos e.details
            'Error en servidor biométrico (${e.details}). Inicia sesión manualmente.',
          );
        }
        // Captura otros errores (red, etc.)
        throw BiometricAuthException(
          'SESSION_ERROR',
          'Error en sesión biométrica. Inicia sesión manualmente.',
        );
      }
    } on BiometricAuthException {
      rethrow;
    } catch (e) {
      print('❌ [LOGIN_BIOMETRIC_B] Error inesperado: $e');
      throw BiometricAuthException(
        'UNKNOWN_ERROR',
        'Error en autenticación biométrica: ${e.toString()}',
      );
    }
  }

  Future<Map<String, dynamic>> enableBiometricForCurrentUser() async {
    try {
      print('🔐 [BIOMETRIC_B] Iniciando habilitación de biometría (Opción B)...');

      final session = _supabase.auth.currentSession;
      final user = _supabase.auth.currentUser;

      if (session == null || user == null) {
        print('❌ [BIOMETRIC_B] No hay sesión activa');
        return {
          'success': false,
          'message': 'No hay sesión activa. Inicia sesión primero.',
        };
      }

      print('✅ [BIOMETRIC_B] Sesión válida');

      final authenticated = await _biometricService.authenticate(
        'Autentícate para habilitar el acceso biométrico',
      );

      if (!authenticated) {
        print('❌ [BIOMETRIC_B] Autenticación biométrica cancelada');
        return {
          'success': false,
          'message': 'Autenticación biométrica cancelada',
        };
      }

      print('✅ [BIOMETRIC_B] Autenticación biométrica exitosa');

      final deviceId = await _getDeviceId();
      final platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown');
      print('📱 [BIOMETRIC_B] Device ID: $deviceId, Platform: $platform');

      // ✅ PASO 1: Generar un token biométrico personalizado
      final secureToken = _generateSecureToken();

      // ✅ PASO 2: Hashear el token para guardarlo en la BD
      final tokenHash = _hashToken(secureToken);

      // ✅ PASO 3: Guardar el token EN CLARO en el almacenamiento seguro
      await _secureStorage.write(key: _keyBiometricToken, value: secureToken);
      await _secureStorage.write(key: _keyUserEmail, value: user.email!);
      await _secureStorage.write(key: _keyDeviceId, value: deviceId);
      print('💾 [BIOMETRIC_B] Token personalizado guardado en almacenamiento seguro');

      // ✅ PASO 4: Registrar el HASH en la nueva tabla biometric_sessions
      try {
        await _supabase.from('biometric_sessions')
            .update({'is_active': false, 'disabled_at': DateTime.now().toIso8601String()})
            .eq('user_id', user.id)
            .eq('device_id', deviceId)
            .eq('is_active', true);

        await _supabase.from('biometric_sessions').insert({
          'user_id': user.id,
          'device_id': deviceId,
          'biometric_token_hash': tokenHash, // Columna renombrada
          'token_version': 1, // Nueva columna
          'platform': platform, // Nueva columna
          'enabled_at': DateTime.now().toIso8601String(),
          'last_used_at': DateTime.now().toIso8601String(),
          'is_active': true,
        });
        print('✅ [BIOMETRIC_B] Hash de token personalizado registrado en biometric_sessions');

      } catch (e) {
        print('❌ [BIOMETRIC_B] Error al registrar hash en BD: $e');
        await _clearBiometricData(); // Limpiar si falla el registro en BD
        return {'success': false, 'message': 'Error al registrar en servidor: ${e.toString()}'};
      }

      // ✅ PASO 5: Registrar dispositivo en user_devices (tu lógica actual)
      try {
        await _deviceService.registerCurrentDevice(user.id);
        print('✅ [BIOMETRIC_B] Dispositivo registrado en user_devices');
      } catch (e) {
        print('❌ [BIOMETRIC_B] Error al registrar dispositivo: $e');
        await _clearBiometricData();
        return {
          'success': false,
          'message': 'Error al registrar dispositivo: ${e.toString()}',
        };
      }

      // ✅ PASO 6: Actualizar flag en users (tu lógica actual)
      await _supabase.from('users').update({
        'biometric_enabled': true,
      }).eq('id', user.id);
      print('✅ [BIOMETRIC_B] Flag biometric_enabled actualizado en users');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyBiometricEnabled, true);

      print('✅ [BIOMETRIC_B] Biometría (Opción B) habilitada exitosamente');
      return {'success': true, 'message': 'Biometría habilitada exitosamente'};

    } catch (e) {
      print('❌ [BIOMETRIC_B] Error al habilitar biometría: $e');
      return {
        'success': false,
        'message': 'Error al habilitar biometría: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> disableBiometricForCurrentUser() async {
    try {
      print('🔐 [BIOMETRIC_DISABLE_B] Deshabilitando biometría (Opción B)...');

      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'No hay sesión activa'};
      }

      final deviceId = await _getDeviceId();
      print('📱 [BIOMETRIC_DISABLE_B] Device ID: $deviceId');

      // ✅ Desactivar en biometric_sessions
      try {
        await _supabase.from('biometric_sessions')
            .update({
          'is_active': false,
          'disabled_at': DateTime.now().toIso8601String(),
        })
            .eq('user_id', user.id)
            .eq('device_id', deviceId)
            .eq('is_active', true);
        print('✅ [BIOMETRIC_DISABLE_B] Sesión biométrica marcada como inactiva');
      } catch (e) {
        print('⚠️ [BIOMETRIC_DISABLE_B] Error al actualizar biometric_sessions: $e');
      }

      // ✅ Desactivar en user_devices
      try {
        final deactivated = await _deviceService.deactivateDevice(user.id, deviceId);
        if (deactivated) {
          print('✅ [BIOMETRIC_DISABLE_B] Dispositivo desactivado en user_devices');
        } else {
          print('⚠️ [BIOMETRIC_DISABLE_B] No se pudo desactivar dispositivo en BD');
        }
      } catch (e) {
        print('❌ [BIOMETRIC_DISABLE_B] Error al desactivar en user_devices: $e');
      }

      // ✅ Limpiar credenciales locales
      await _clearBiometricData();
      print('✅ [BIOMETRIC_DISABLE_B] Credenciales locales limpiadas');

      // ✅ Verificar si hay otros dispositivos activos
      try {
        final activeDevices = await _deviceService.getActiveDevices(user.id);
        final hasOtherDevices = activeDevices.isNotEmpty;

        print('📱 [BIOMETRIC_DISABLE_B] Dispositivos activos restantes: ${activeDevices.length}');

        await _supabase.from('users').update({
          'biometric_enabled': hasOtherDevices,
        }).eq('id', user.id);

        print('✅ [BIOMETRIC_DISABLE_B] Flag biometric_enabled=${hasOtherDevices.toString()} en users');
      } catch (e) {
        print('⚠️ [BIOMETRIC_DISABLE_B] Error al verificar otros dispositivos: $e');
        await _supabase.from('users').update({
          'biometric_enabled': false,
        }).eq('id', user.id);
      }

      print('✅ [BIOMETRIC_DISABLE_B] Biometría deshabilitada exitosamente');

      try {
        await _supabase.auth.signOut(scope: SignOutScope.local);
      } catch (e) {
        print('⚠️ [LOGOUT] Error en signOut local (continuando): $e');
      }

      return {
        'success': true,
        'message': 'Biometría deshabilitada en este dispositivo',
      };
    } catch (e) {
      print('❌ [BIOMETRIC_DISABLE_B] Error inesperado: $e');
      return {
        'success': false,
        'message': 'Error al deshabilitar biometría: ${e.toString()}',
      };
    }
  }

  Future<bool> checkBiometricStatus() async {
    try {
      print('🔍 [BIOMETRIC_B] Verificando estado biométrico (Opción B)...');

      final biometricToken = await _secureStorage.read(key: _keyBiometricToken);
      final deviceId = await _secureStorage.read(key: _keyDeviceId);
      final userEmail = await _secureStorage.read(key: _keyUserEmail);

      final hasCredentials = biometricToken != null &&
          deviceId != null &&
          userEmail != null;

      print('🔍 [BIOMETRIC_B] Credenciales personalizadas encontradas: $hasCredentials');
      print('🔍 [BIOMETRIC_B] Email: $userEmail');

      if (hasCredentials) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyBiometricEnabled, true);
      }

      return hasCredentials;
    } catch (e) {
      print('❌ [BIOMETRIC_B] Error al verificar estado biométrico: $e');
      return false;
    }
  }

  Future<Map<String, String>?> getStoredBiometricUserInfo() async {
    try {
      print('🔍 [BIOMETRIC_B] Obteniendo info de usuario desde credenciales guardadas...');

      final userEmail = await _secureStorage.read(key: _keyUserEmail);
      final deviceId = await _secureStorage.read(key: _keyDeviceId);

      if (userEmail == null || deviceId == null) {
        print('🔍 [BIOMETRIC_B] No hay credenciales completas guardadas');
        return null;
      }

      print('🔍 [BIOMETRIC_B] Usuario encontrado: $userEmail');
      return {
        'email': userEmail,
        'deviceId': deviceId,
      };
    } catch (e) {
      print('❌ [BIOMETRIC_B] Error al obtener info de usuario: $e');
      return null;
    }
  }

  // ==========================================================================
  // MÉTODOS AUXILIARES PRIVADOS (OPCIÓN B)
  // ==========================================================================

  Future<void> _clearBiometricData() async {
    try {
      print('🧹 [BIOMETRIC_B] Limpiando datos biométricos personalizados...');

      await _secureStorage.delete(key: _keyBiometricToken);
      await _secureStorage.delete(key: _keyUserEmail);
      await _secureStorage.delete(key: _keyDeviceId);

      await _secureStorage.delete(key: 'biometric_refresh_token');
      await _secureStorage.delete(key: 'biometric_access_token');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyBiometricEnabled);

      print('✅ [BIOMETRIC_B] Datos biométricos limpiados');
    } catch (e) {
      print('❌ [BIOMETRIC_B] Error al limpiar datos: $e');
    }
  }

  Future<String> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId;

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown_ios';
      } else {
        deviceId = 'unknown_platform';
      }

      print('📱 [AUTH_SERVICE] Device ID obtenido: $deviceId');
      return deviceId;
    } catch (e) {
      print('❌ Error al obtener Device ID: $e');
      return 'error_device_id';
    }
  }

  String _hashToken(String token) {
    try {
      final bytes = utf8.encode(token);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('⚠️ [AUTH_SERVICE] Error al hashear token: $e');
      return token;
    }
  }

  String _generateSecureToken([int length = 32]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64UrlEncode(values);
  }
}
