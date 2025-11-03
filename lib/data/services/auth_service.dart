// lib/data/services/auth_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
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

      // ✅ CRÍTICO: Verificar si hay biometría habilitada
      final hasBiometric = await checkBiometricStatus();

      if (hasBiometric) {
        // ✅ Si tiene biometría: NO llamar a signOut() porque invalida el refresh token
        // En su lugar, solo limpiar la sesión local manualmente
        print('🔐 [LOGOUT] Usuario tiene biometría habilitada');
        print('🔐 [LOGOUT] Limpiando sesión local SIN invalidar tokens en servidor');

        // Acceder al storage interno de Supabase para limpiar solo la sesión local
        // Esto NO invalida el refresh token en el servidor
        try {
          await _supabase.auth.signOut(scope: SignOutScope.local);
        } catch (e) {
          print('⚠️ [LOGOUT] Error en signOut local (continuando): $e');
        }

        print('✅ [LOGOUT] Sesión local limpiada (tokens biométricos siguen válidos en servidor)');
      } else {
        // ✅ Si NO tiene biometría: Hacer logout normal (invalida tokens)
        print('🔐 [LOGOUT] Usuario sin biometría, logout normal');
        await _supabase.auth.signOut();
        print('✅ [LOGOUT] Sesión cerrada completamente');
      }
    } catch (e) {
      print('❌ [LOGOUT] Error al cerrar sesión: $e');
      // No lanzar excepción, permitir que el logout continúe
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
      print('🔄 [LOGIN_BIOMETRIC] Restaurando sesión desde refresh token...');

      try {
        var response = await _supabase.auth.setSession(refreshToken);

        if (response.session == null || response.user == null) {
           print('❌ [LOGIN_BIOMETRIC] No se pudo restaurar la sesión, intentando renovar...');
           final renewed = await _renewBiometricCredentials();
           if (!renewed) {
             await _clearBiometricData();
             throw BiometricAuthException(
               'SESSION_EXPIRED',
               'Sesión biométrica expirada. Inicia sesión manualmente.',
             );
           }
           final newToken = await _secureStorage.read(key: _keyRefreshToken);
           response = await _supabase.auth.setSession(newToken!);
           if (response.session == null || response.user == null) {
             await _clearBiometricData();
             throw BiometricAuthException(
               'SESSION_EXPIRED',
               'Sesión biométrica expirada. Inicia sesión manualmente.',
             );
           }
         }
        
        print('✅ [LOGIN_BIOMETRIC] Sesión restaurada exitosamente');

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

        await _deviceService.updateDeviceLastUsed(response.user!.id, deviceId);

        // Actualizar el refresh token en el almacenamiento seguro con el nuevo token
        await _secureStorage.write(
          key: _keyRefreshToken,
          value: response.session!.refreshToken,
        );

        print('✅ [LOGIN_BIOMETRIC] Token actualizado en almacenamiento seguro');

        // Actualizar last_used_at en biometric_sessions
        try {
          await _supabase
              .from('biometric_sessions')
              .update({
                'last_used_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('user_id', response.user!.id)
              .eq('device_id', deviceId)
              .eq('is_active', true);
          print('✅ [LOGIN_BIOMETRIC] last_used_at actualizado en biometric_sessions');
        } catch (e) {
          print('⚠️ [LOGIN_BIOMETRIC] Error al actualizar last_used_at: $e');
        }

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
          biometricEnabled: true,
          biometricToken: userData['biometric_token'],
          deviceId: deviceId,
          dni: userData['dni'],
          phone: userData['phone'],
          address: userData['address'],
        );

        print(
          '✅ [LOGIN_BIOMETRIC] Login biométrico completado para: ${user.email}',
        );
        return user;
      } catch (e) {
        print('❌ [LOGIN_BIOMETRIC] Error al restaurar sesión: $e');
        
        if (e.toString().contains('Invalid Refresh Token') || 
            e.toString().contains('refresh_token_not_found')) {
          print('❌ [LOGIN_BIOMETRIC] Refresh token inválido, limpiando credenciales...');
          
          // Limpiar credenciales locales
          await _clearBiometricData();
          
          // Marcar sesión biométrica como inactiva en la base de datos
          try {
            final deviceId = await _secureStorage.read(key: _keyDeviceId);
            if (deviceId != null) {
              await _supabase.from('biometric_sessions')
                .update({
                  'is_active': false,
                  'disabled_at': DateTime.now().toIso8601String(),
                })
                .eq('device_id', deviceId)
                .eq('is_active', true);
              print('✅ [LOGIN_BIOMETRIC] Sesión biométrica marcada como inactiva en BD');
            }
          } catch (dbError) {
            print('⚠️ [LOGIN_BIOMETRIC] Error al actualizar sesión en BD: $dbError');
          }
          
          throw BiometricAuthException(
            'CREDENTIALS_EXPIRED',
            'Credenciales biométricas expiradas. Inicia sesión manualmente.',
          );
        }
        
        print('❌ [LOGIN_BIOMETRIC] Error crítico, limpiando credenciales');
        await _clearBiometricData();
        throw BiometricAuthException(
          'SESSION_ERROR',
          'Error en sesión biométrica. Inicia sesión manualmente.',
        );
      }
    } on BiometricAuthException {
      rethrow;
    } catch (e) {
      print('❌ [LOGIN_BIOMETRIC] Error inesperado: $e');
      if (e.toString().contains('PlatformException') || 
          e.toString().contains('BiometricException')) {
        print('❌ [LOGIN_BIOMETRIC] Error de biometría, limpiando credenciales');
        await _clearBiometricData();
      }
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

      // ✅ NUEVO: Registrar sesión biométrica en biometric_sessions
      try {
        // Primero desactivar cualquier sesión anterior del mismo dispositivo
        await _supabase.from('biometric_sessions')
          .update({
            'is_active': false,
            'disabled_at': DateTime.now().toIso8601String(),
          })
          .eq('device_id', deviceId)
          .eq('is_active', true);
        
        // Crear nueva sesión biométrica
        if (session.refreshToken != null) {
          final sessionTokenHash = _hashToken(session.refreshToken!);
          await _supabase.from('biometric_sessions').insert({
            'user_id': user.id,
            'device_id': deviceId,
            'session_token_hash': sessionTokenHash,
            'enabled_at': DateTime.now().toIso8601String(),
            'last_used_at': DateTime.now().toIso8601String(),
            'is_active': true,
          });
        } else {
          print('⚠️ [BIOMETRIC] No hay refresh token para hashear');
        }
        
        print('✅ [BIOMETRIC] Sesión biométrica registrada en biometric_sessions');
      } catch (e) {
        print('⚠️ [BIOMETRIC] Error al registrar sesión en biometric_sessions: $e');
        // No fallar el proceso si hay error en esta tabla
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

      // ✅ Marcar sesión biométrica como inactiva en biometric_sessions
      try {
        await _supabase.from('biometric_sessions')
          .update({
            'is_active': false,
            'disabled_at': DateTime.now().toIso8601String(),
          })
          .eq('device_id', deviceId)
          .eq('is_active', true);
        print('✅ [BIOMETRIC_DISABLE] Sesión biométrica marcada como inactiva en biometric_sessions');
      } catch (e) {
        print('⚠️ [BIOMETRIC_DISABLE] Error al actualizar biometric_sessions: $e');
      }

      // ✅ Limpiar credenciales locales
      await _clearBiometricData();
      print('✅ [BIOMETRIC_DISABLE] Credenciales locales limpiadas');

      // ✅ Verificar si hay otros dispositivos activos
      try {
        final activeDevices = await _deviceService.getActiveDevices(user.id);
        final hasOtherDevices = activeDevices.isNotEmpty;

        print('📱 [BIOMETRIC_DISABLE] Dispositivos activos restantes: ${activeDevices.length}');

        // ✅ Siempre actualizar biometric_enabled basado en dispositivos activos
        await _supabase.from('users').update({
          'biometric_enabled': hasOtherDevices,
        }).eq('id', user.id);
        
        print('✅ [BIOMETRIC_DISABLE] Flag biometric_enabled=${hasOtherDevices.toString()} en users');
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

  /// Obtiene la información del usuario guardada en las credenciales biométricas
  Future<Map<String, String>?> getStoredBiometricUserInfo() async {
    try {
      print('🔍 [BIOMETRIC] Obteniendo info de usuario desde credenciales guardadas...');

      final userEmail = await _secureStorage.read(key: _keyUserEmail);
      final deviceId = await _secureStorage.read(key: _keyDeviceId);

      if (userEmail == null || deviceId == null) {
        print('🔍 [BIOMETRIC] No hay credenciales completas guardadas');
        return null;
      }

      print('🔍 [BIOMETRIC] Usuario encontrado: $userEmail');
      return {
        'email': userEmail,
        'deviceId': deviceId,
      };
    } catch (e) {
      print('❌ [BIOMETRIC] Error al obtener info de usuario: $e');
      return null;
    }
  }

  // ==========================================================================
  // MÉTODOS AUXILIARES PRIVADOS
  // ==========================================================================

  /// Intenta renovar las credenciales biométricas guardadas
  Future<bool> _renewBiometricCredentials() async {
    try {
      print('🔄 [BIOMETRIC] Intentando renovar credenciales biométricas...');

      final refreshToken = await _secureStorage.read(key: _keyRefreshToken);
      final deviceId = await _secureStorage.read(key: _keyDeviceId);
      final userEmail = await _secureStorage.read(key: _keyUserEmail);

      if (refreshToken == null || deviceId == null || userEmail == null) {
        print('❌ [BIOMETRIC] Credenciales incompletas para renovar');
        return false;
      }

      // Intentar renovar el token con Supabase
      final response = await _supabase.auth.refreshSession(refreshToken);
      
      if (response.session == null) {
        print('❌ [BIOMETRIC] No se pudo renovar la sesión');
        return false;
      }

      // Guardar las nuevas credenciales
      await _secureStorage.write(
        key: _keyRefreshToken,
        value: response.session!.refreshToken,
      );

      print('✅ [BIOMETRIC] Credenciales renovadas exitosamente');
      return true;
    } catch (e) {
      print('❌ [BIOMETRIC] Error al renovar credenciales: $e');
      return false;
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

      print('📱 [AUTH_SERVICE] Device ID obtenido: $deviceId');
      return deviceId;
    } catch (e) {
      print('❌ Error al obtener Device ID: $e');
      return 'error_device_id';
    }
  }

  /// Hashea un token para almacenarlo de forma segura en la base de datos
  String _hashToken(String token) {
    try {
      // Usar SHA-256 para hashear el token
      final bytes = utf8.encode(token);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('⚠️ [AUTH_SERVICE] Error al hashear token: $e');
      // Fallback: usar el token original (no recomendado pero evita errores)
      return token;
    }
  }
}
