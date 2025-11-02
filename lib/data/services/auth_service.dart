// lib/data/services/auth_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
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
  static const String _keyRefreshToken = 'biometric_refresh_token';
  static const String _keyAccessToken = 'biometric_access_token';
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

      // ✅ CRÍTICO: Si el usuario tiene biometría habilitada en BD,
      // DEBEMOS guardar los tokens de ESTA sesión activa
      // Esto reemplaza cualquier token viejo (invalidado por logout anterior)
      if (user.biometricEnabled && response.session != null) {
        print('🔄 [LOGIN_EMAIL] Usuario tiene biometría habilitada, guardando tokens de sesión activa...');

        final deviceId = await _getDeviceId();

        // Guardar TODAS las credenciales necesarias
        await _secureStorage.write(
          key: _keyRefreshToken,
          value: response.session!.refreshToken,
        );
        await _secureStorage.write(
          key: _keyAccessToken,
          value: response.session!.accessToken,
        );
        await _secureStorage.write(key: _keyUserEmail, value: user.email);
        await _secureStorage.write(key: _keyDeviceId, value: deviceId);

        // Actualizar flag local
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyBiometricEnabled, true);

        print('✅ [LOGIN_EMAIL] Credenciales biométricas guardadas (tokens VÁLIDOS de sesión activa)');

        // Verificar si el dispositivo está registrado en user_devices
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
            // Actualizar last_used_at
            await _deviceService.updateDeviceLastUsed(user.id, deviceId);
          }
        } catch (e) {
          print('⚠️ [LOGIN_EMAIL] Error al verificar/registrar dispositivo: $e');
          // No fallar el login por esto
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

      // ✅ IMPORTANTE: NO limpiar credenciales biométricas en logout
      // Las credenciales deben persistir para permitir login biométrico
      // Solo se limpian cuando el usuario DESHABILITA la biometría explícitamente

      await _supabase.auth.signOut();

      print('✅ [LOGOUT] Sesión cerrada (credenciales biométricas preservadas)');
    } catch (e) {
      print('❌ [LOGOUT] Error al cerrar sesión: $e');
      throw AuthServiceException('LOGOUT_ERROR', 'Error al cerrar sesión');
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
        final profileResponse = await _supabase.rpc(
          'register_user',
          params: {
            'p_user_id': user.id,
            'p_email': email,
            'p_name': name,
            'p_role': role,
            'p_dni': dni,
            'p_phone': phone,
            'p_address': address,
          },
        );

        if (profileResponse == null) {
          throw UserProfileException(
            'PROFILE_CREATION_FAILED',
            'No se recibió respuesta al crear el perfil de usuario.',
          );
        }

        final result = profileResponse as Map<String, dynamic>;
        final success = result['success'] as bool? ?? false;
        final message = result['message'] as String? ?? 'Error desconocido';

        if (!success) {
          print('❌ [REGISTER] Error al crear perfil: $message');
          try {
            await _supabase.auth.signOut(scope: SignOutScope.local);
          } catch (_) {}
          throw UserProfileException('PROFILE_CREATION_FAILED', message);
        }

        print('✅ [REGISTER] Perfil creado exitosamente');

        return UserModel(
          id: user.id,
          name: name,
          email: email,
          role: UserModel.roleFromString(result['role'] as String? ?? role),
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
  // MÉTODOS DE AUTENTICACIÓN BIOMÉTRICA
  // ==========================================================================

  Future<UserModel?> loginWithBiometrics() async {
    try {
      print('🔐 [LOGIN_BIOMETRIC] Iniciando login biométrico...');

      final authenticated = await _biometricService.authenticate(
        'Autentícate para acceder a la aplicación',
      );

      if (!authenticated) {
        print(
          '❌ [LOGIN_BIOMETRIC] Autenticación biométrica fallida o cancelada',
        );
        throw BiometricAuthException(
          'AUTH_FAILED',
          'Autenticación biométrica fallida o cancelada',
        );
      }

      print('✅ [LOGIN_BIOMETRIC] Autenticación biométrica exitosa');

      final refreshToken = await _secureStorage.read(key: _keyRefreshToken);
      final deviceId = await _secureStorage.read(key: _keyDeviceId);
      final userEmail = await _secureStorage.read(key: _keyUserEmail);

      if (refreshToken == null || deviceId == null) {
        print('❌ [LOGIN_BIOMETRIC] Credenciales no encontradas');
        await _clearBiometricData();
        throw BiometricAuthException(
          'CREDENTIALS_NOT_FOUND',
          'Credenciales biométricas no encontradas',
        );
      }

      print('📱 [LOGIN_BIOMETRIC] Credenciales encontradas para: $userEmail');
      print('🔄 [LOGIN_BIOMETRIC] Intentando refrescar sesión...');

      final response = await _supabase.auth.refreshSession(refreshToken);

      if (response.session == null || response.user == null) {
        print('❌ [LOGIN_BIOMETRIC] No se pudo refrescar la sesión');
        await _clearBiometricData();
        throw BiometricAuthException(
          'SESSION_EXPIRED',
          'Sesión biométrica expirada. Inicia sesión manualmente.',
        );
      }

      print('✅ [LOGIN_BIOMETRIC] Sesión refrescada exitosamente');

      // ✅ NUEVO: Verificar en tabla user_devices en lugar de users
      final isRegistered = await _deviceService.isDeviceRegistered(
        response.user!.id,
        deviceId,
      );

      if (!isRegistered) {
        print('❌ [LOGIN_BIOMETRIC] Dispositivo no registrado o inactivo');
        await _clearBiometricData();
        throw BiometricAuthException(
          'DEVICE_NOT_REGISTERED',
          'Este dispositivo no está registrado. Inicia sesión manualmente.',
        );
      }

      print('✅ [LOGIN_BIOMETRIC] Dispositivo verificado en user_devices');

      // ✅ NUEVO: Actualizar last_used_at del dispositivo
      await _deviceService.updateDeviceLastUsed(response.user!.id, deviceId);

      await _renewBiometricCredentials(response.session!);

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
        biometricEnabled: true, // ✅ El usuario tiene biometría en ESTE dispositivo
        biometricToken: userData['biometric_token'],
        deviceId: deviceId, // ✅ Usar el deviceId actual
        dni: userData['dni'],
        phone: userData['phone'],
        address: userData['address'],
      );

      print(
        '✅ [LOGIN_BIOMETRIC] Login biométrico completado para: ${user.email}',
      );
      return user;
    } on BiometricAuthException {
      rethrow;
    } catch (e) {
      print('❌ [LOGIN_BIOMETRIC] Error inesperado: $e');
      await _clearBiometricData();
      throw BiometricAuthException(
        'UNKNOWN_ERROR',
        'Error en autenticación biométrica: ${e.toString()}',
      );
    }
  }

  Future<Map<String, dynamic>> enableBiometricForCurrentUser() async {
    try {
      print('🔐 [BIOMETRIC] Iniciando habilitación de biometría...');

      final session = _supabase.auth.currentSession;
      final user = _supabase.auth.currentUser;

      if (session == null || user == null) {
        print('❌ [BIOMETRIC] No hay sesión activa');
        return {
          'success': false,
          'message': 'No hay sesión activa. Inicia sesión primero.',
        };
      }

      print('✅ [BIOMETRIC] Sesión válida');

      final authenticated = await _biometricService.authenticate(
        'Autentícate para habilitar el acceso biométrico',
      );

      if (!authenticated) {
        print('❌ [BIOMETRIC] Autenticación biométrica cancelada');
        return {
          'success': false,
          'message': 'Autenticación biométrica cancelada',
        };
      }

      print('✅ [BIOMETRIC] Autenticación biométrica exitosa');

      final deviceId = await _getDeviceId();
      print('📱 [BIOMETRIC] Device ID: $deviceId');

      // ✅ Guardar credenciales localmente
      await _secureStorage.write(
        key: _keyRefreshToken,
        value: session.refreshToken,
      );
      await _secureStorage.write(
        key: _keyAccessToken,
        value: session.accessToken,
      );
      await _secureStorage.write(key: _keyUserEmail, value: user.email);
      await _secureStorage.write(key: _keyDeviceId, value: deviceId);
      print('💾 [BIOMETRIC] Credenciales guardadas en almacenamiento seguro');

      // ✅ NUEVO: Registrar dispositivo en user_devices
      try {
        await _deviceService.registerCurrentDevice(user.id);
        print('✅ [BIOMETRIC] Dispositivo registrado en user_devices');
      } catch (e) {
        print('❌ [BIOMETRIC] Error al registrar dispositivo: $e');
        // Limpiar credenciales si falla el registro
        await _clearBiometricData();
        return {
          'success': false,
          'message': 'Error al registrar dispositivo: ${e.toString()}',
        };
      }

      // ✅ MANTENER: Actualizar users.biometric_enabled para compatibilidad
      // (Este campo se usará como flag general, no para validación de dispositivo)
      await _supabase.from('users').update({
        'biometric_enabled': true,
      }).eq('id', user.id);

      print('✅ [BIOMETRIC] Flag biometric_enabled actualizado en users');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyBiometricEnabled, true);

      print('✅ [BIOMETRIC] Biometría habilitada exitosamente');

      return {'success': true, 'message': 'Biometría habilitada exitosamente'};
    } catch (e) {
      print('❌ [BIOMETRIC] Error al habilitar biometría: $e');
      return {
        'success': false,
        'message': 'Error al habilitar biometría: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> disableBiometricForCurrentUser() async {
    try {
      print('🔐 [BIOMETRIC_DISABLE] Deshabilitando biometría en este dispositivo...');

      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'No hay sesión activa'};
      }

      final deviceId = await _getDeviceId();
      print('📱 [BIOMETRIC_DISABLE] Device ID: $deviceId');

      // ✅ Desactivar dispositivo en user_devices PRIMERO
      try {
        final deactivated = await _deviceService.deactivateDevice(user.id, deviceId);
        if (deactivated) {
          print('✅ [BIOMETRIC_DISABLE] Dispositivo desactivado en user_devices');
        } else {
          print('⚠️ [BIOMETRIC_DISABLE] No se pudo desactivar dispositivo en BD');
        }
      } catch (e) {
        print('❌ [BIOMETRIC_DISABLE] Error al desactivar en user_devices: $e');
      }

      // ✅ Limpiar credenciales locales
      await _clearBiometricData();
      print('✅ [BIOMETRIC_DISABLE] Credenciales locales limpiadas');

      // ✅ Verificar si hay otros dispositivos activos
      try {
        final activeDevices = await _deviceService.getActiveDevices(user.id);
        final hasOtherDevices = activeDevices.isNotEmpty;

        print('📱 [BIOMETRIC_DISABLE] Dispositivos activos restantes: ${activeDevices.length}');

        // ✅ Solo actualizar biometric_enabled a false si no hay otros dispositivos
        if (!hasOtherDevices) {
          await _supabase.from('users').update({
            'biometric_enabled': false,
          }).eq('id', user.id);
          print('✅ [BIOMETRIC_DISABLE] Flag biometric_enabled=false en users (no hay otros dispositivos)');
        } else {
          print(
            'ℹ️ [BIOMETRIC_DISABLE] Hay ${activeDevices.length} dispositivos activos, manteniendo biometric_enabled=true',
          );
        }
      } catch (e) {
        print('⚠️ [BIOMETRIC_DISABLE] Error al verificar otros dispositivos: $e');
        // Por seguridad, actualizar biometric_enabled a false
        await _supabase.from('users').update({
          'biometric_enabled': false,
        }).eq('id', user.id);
      }

      print('✅ [BIOMETRIC_DISABLE] Biometría deshabilitada exitosamente en este dispositivo');

      return {
        'success': true,
        'message': 'Biometría deshabilitada en este dispositivo',
      };
    } catch (e) {
      print('❌ [BIOMETRIC_DISABLE] Error inesperado: $e');
      return {
        'success': false,
        'message': 'Error al deshabilitar biometría: ${e.toString()}',
      };
    }
  }

  Future<bool> checkBiometricStatus() async {
    try {
      print('🔍 [BIOMETRIC] Verificando estado biométrico...');

      // ✅ CORREGIDO: Verificar directamente si hay credenciales guardadas
      // No depender solo del flag de SharedPreferences
      final refreshToken = await _secureStorage.read(key: _keyRefreshToken);
      final deviceId = await _secureStorage.read(key: _keyDeviceId);
      final userEmail = await _secureStorage.read(key: _keyUserEmail);

      final hasCredentials = refreshToken != null &&
                            deviceId != null &&
                            userEmail != null;

      print('🔍 [BIOMETRIC] Credenciales encontradas: $hasCredentials');
      print('🔍 [BIOMETRIC] Email: $userEmail');

      if (hasCredentials) {
        // Actualizar flag en SharedPreferences si existe
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyBiometricEnabled, true);
      }

      return hasCredentials;
    } catch (e) {
      print('❌ [BIOMETRIC] Error al verificar estado biométrico: $e');
      return false;
    }
  }

  // ==========================================================================
  // MÉTODOS AUXILIARES PRIVADOS
  // ==========================================================================

  Future<void> _renewBiometricCredentials(Session session) async {
    try {
      print('🔄 [BIOMETRIC] Renovando credenciales biométricas...');

      // Renovar tokens
      await _secureStorage.write(
        key: _keyRefreshToken,
        value: session.refreshToken,
      );
      await _secureStorage.write(
        key: _keyAccessToken,
        value: session.accessToken,
      );

      // ✅ IMPORTANTE: También guardar email y device_id si no existen
      // Esto asegura que checkBiometricStatus() funcione correctamente
      final existingEmail = await _secureStorage.read(key: _keyUserEmail);
      if (existingEmail == null && session.user?.email != null) {
        await _secureStorage.write(
          key: _keyUserEmail,
          value: session.user!.email!,
        );
        print('📧 [BIOMETRIC] Email guardado: ${session.user!.email}');
      }

      final existingDeviceId = await _secureStorage.read(key: _keyDeviceId);
      if (existingDeviceId == null) {
        final deviceId = await _getDeviceId();
        await _secureStorage.write(
          key: _keyDeviceId,
          value: deviceId,
        );
        print('📱 [BIOMETRIC] Device ID guardado: $deviceId');
      }

      print('✅ [BIOMETRIC] Credenciales renovadas exitosamente');
    } catch (e) {
      print('❌ [BIOMETRIC] Error al renovar credenciales: $e');
    }
  }

  Future<void> _clearBiometricData() async {
    try {
      print('🧹 [BIOMETRIC] Limpiando datos biométricos...');

      await _secureStorage.delete(key: _keyRefreshToken);
      await _secureStorage.delete(key: _keyAccessToken);
      await _secureStorage.delete(key: _keyUserEmail);
      await _secureStorage.delete(key: _keyDeviceId);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyBiometricEnabled);

      print('✅ [BIOMETRIC] Datos biométricos limpiados');
    } catch (e) {
      print('❌ [BIOMETRIC] Error al limpiar datos: $e');
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

      final user = _supabase.auth.currentUser;
      return '${deviceId}_${user?.id ?? "unknown"}';
    } catch (e) {
      print('❌ Error al obtener Device ID: $e');
      return 'error_device_id';
    }
  }
}
