import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_gobiernoti/data/models/user_model.dart';
import 'package:app_gobiernoti/data/services/biometric_service.dart';
import 'package:app_gobiernoti/data/services/audit_service.dart';
import 'package:app_gobiernoti/core/locator.dart';

/// Excepción personalizada para errores de autenticación
class AuthServiceException implements Exception {
  final String code;
  final String message;

  AuthServiceException(this.code, this.message);

  @override
  String toString() => message;
}

/// Excepción personalizada para errores de autenticación biométrica
class BiometricAuthException implements Exception {
  final String code;
  final String message;

  BiometricAuthException(this.code, this.message);

  @override
  String toString() => message;
}

/// Excepción personalizada para errores de perfil de usuario
class UserProfileException implements Exception {
  final String code;
  final String message;

  UserProfileException(this.code, this.message);

  @override
  String toString() => message;
}

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final BiometricService _biometricService = locator<BiometricService>();
  final AuditService _auditService = AuditService();

  final _secureStorage = const FlutterSecureStorage();

  IOSOptions get _iosOptions => const IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );
  AndroidOptions get _androidOptions =>
      const AndroidOptions(encryptedSharedPreferences: true);

  // 🔧 CAMBIO: Ahora guardamos el device_id junto con el refresh_token
  static const String _refreshTokenKey = 'supabase_refresh_token';
  static const String _deviceIdKey = 'device_id';
  static const String _biometricEnabledKey = 'biometric_enabled';

  /// Genera un ID único para el dispositivo actual
  Future<String> _getOrCreateDeviceId() async {
    String? deviceId = await _secureStorage.read(
      key: _deviceIdKey,
      iOptions: _iosOptions,
      aOptions: _androidOptions,
    );

    if (deviceId == null) {
      deviceId =
          '${DateTime.now().millisecondsSinceEpoch}_${_supabase.auth.currentUser?.id ?? "anon"}';
      await _secureStorage.write(
        key: _deviceIdKey,
        value: deviceId,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );
      print('🔐 [DEVICE_ID] Nuevo device_id generado: $deviceId');
    } else {
      print('🔐 [DEVICE_ID] Device_id existente: $deviceId');
    }

    return deviceId;
  }

  /// Inicia sesión con email y contraseña.
  Future<UserModel> loginWithEmail(String email, String password) async {
    try {
      print('🔐 [LOGIN_EMAIL] Iniciando login con email...');
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null) {
        print('✅ [LOGIN_EMAIL] Login exitoso, obteniendo perfil...');
        final userProfile = await _getUserProfile(user.id);

        print(
          '👤 [LOGIN_EMAIL] Perfil obtenido. Biometría habilitada: ${userProfile.biometricEnabled}',
        );

        // Registrar login exitoso en auditoría
        await _auditService.logLoginAttempt(email, success: true);

        // 🔧 CAMBIO CRÍTICO: Si el usuario tenía biometría habilitada, renovar credenciales
        if (userProfile.biometricEnabled) {
          print(
            '🔄 [LOGIN_EMAIL] Renovando credenciales biométricas automáticamente...',
          );
          await _renewBiometricCredentials();
          print('✅ [LOGIN_EMAIL] Renovación de credenciales completada');
        }

        return userProfile;
      } else {
        await _auditService.logLoginAttempt(
          email,
          success: false,
          error: 'Usuario no encontrado',
        );
        throw Exception('Usuario no encontrado');
      }
    } on AuthException catch (e) {
      await _auditService.logLoginAttempt(
        email,
        success: false,
        error: e.message,
      );
      throw Exception('Error de autenticación: ${e.message}');
    } catch (e) {
      await _auditService.logLoginAttempt(
        email,
        success: false,
        error: e.toString(),
      );
      throw Exception('Error desconocido: ${e.toString()}');
    }
  }

  /// Cierra la sesión del usuario.
  Future<void> signOut() async {
    final currentUser = _supabase.auth.currentUser;
    final userId = currentUser?.id;
    final email = currentUser?.email;

    await _supabase.auth.signOut(scope: SignOutScope.local);

    // Registrar logout en auditoría
    await _auditService.logLogout(userId, email);
  }

  /// Obtiene el perfil de usuario desde la tabla users directamente.
  Future<UserModel> _getUserProfile(String userId) async {
    try {
      print('🔍 [PROFILE] Obteniendo perfil para usuario: $userId');

      final response = await _supabase
          .from('users')
          .select(
            'id, name, email, role, dni, phone, address, biometric_enabled',
          )
          .eq('id', userId)
          .single();

      print('🔍 [PROFILE] Respuesta de la consulta: $response');
      print('🔍 [PROFILE] Rol obtenido de la BD: ${response['role']}');

      if (response != null) {
        final biometricEnabled = response['biometric_enabled'] ?? false;
        final roleFromDB = response['role'];
        final convertedRole = UserModel.roleFromString(roleFromDB);

        print(
          '🔍 [PROFILE] Usuario: ${response['email']}, biometricEnabled desde DB: $biometricEnabled',
        );
        print(
          '🔍 [PROFILE] Rol desde BD: "$roleFromDB" -> Convertido a: $convertedRole',
        );

        return UserModel(
          id: response['id'],
          name: response['name'],
          email: response['email'],
          role: UserModel.roleFromString(roleFromDB),
          biometricEnabled: biometricEnabled,
          dni: response['dni'],
          phone: response['phone'],
          address: response['address'],
        );
      } else {
        throw Exception('No se encontró el perfil del usuario');
      }
    } catch (e) {
      print('❌ [PROFILE] Error al obtener perfil: $e');

      if (e.toString().contains('row-level security policy') ||
          e.toString().contains('infinite recursion detected')) {
        print(
          '⚠️ [PROFILE] Error de política RLS detectado - usando datos básicos del usuario Auth',
        );

        final currentUser = _supabase.auth.currentUser;
        if (currentUser != null && currentUser.id == userId) {
          String? roleFromJWT;
          try {
            final session = _supabase.auth.currentSession;
            if (session != null) {
              final payload = session.accessToken.split('.')[1];
              final normalizedPayload = base64Url.normalize(payload);
              final decodedPayload = utf8.decode(
                base64Url.decode(normalizedPayload),
              );
              final Map<String, dynamic> jwtData = json.decode(decodedPayload);
              roleFromJWT = jwtData['role'] as String?;
              print('🔍 [PROFILE] Rol obtenido del JWT: $roleFromJWT');
            }
          } catch (jwtError) {
            print('⚠️ [PROFILE] Error al decodificar JWT: $jwtError');
          }

          final userRole =
              roleFromJWT ??
              currentUser.userMetadata?['role'] ??
              'auditor_junior';

          print('🔍 [PROFILE] Rol final asignado: $userRole');

          return UserModel(
            id: currentUser.id,
            name: currentUser.userMetadata?['name'] ?? 'Usuario',
            email: currentUser.email ?? '',
            role: UserModel.roleFromString(userRole),
            biometricEnabled: false,
            dni: currentUser.userMetadata?['dni'],
            phone: currentUser.userMetadata?['phone'],
            address: currentUser.userMetadata?['address'],
          );
        }
      }

      throw Exception('Error al obtener perfil de usuario: ${e.toString()}');
    }
  }

  /// Registra un nuevo usuario.
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
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('No se pudo crear el usuario en Auth.');
      }

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

      if (profileResponse != null && profileResponse['success'] == true) {
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
      } else {
        print(
          'Error al registrar perfil, pero el usuario de Auth ya fue creado.',
        );
        throw Exception(
          profileResponse?['message'] ??
              'Error al registrar el perfil de usuario.',
        );
      }
    } on AuthException catch (e) {
      throw Exception('Error de registro: ${e.message}');
    } catch (e) {
      throw Exception('Error desconocido: ${e.toString()}');
    }
  }

  // =======================================================================
  // FLUJO BIOMÉTRICO SEGURO - CORREGIDO
  // =======================================================================

  /// 🔧 CORRECCIÓN: Habilita el inicio de sesión biométrico
  Future<Map<String, dynamic>> enableBiometricForCurrentUser() async {
    try {
      print('🔐 [BIOMETRIC] Iniciando habilitación de biometría...');

      final isAvailable = await _biometricService.hasBiometrics();
      if (!isAvailable) {
        print('❌ [BIOMETRIC] Biometría no disponible');
        return {'success': false, 'message': 'Biometría no disponible'};
      }

      final isAuthenticated = await _biometricService.authenticate(
        'Confirma tu identidad para habilitar el acceso rápido',
      );
      if (!isAuthenticated) {
        print('❌ [BIOMETRIC] Autenticación biométrica cancelada');
        return {'success': false, 'message': 'Autenticación cancelada'};
      }

      final currentSession = _supabase.auth.currentSession;
      if (currentSession == null) {
        print('❌ [BIOMETRIC] No hay sesión activa');
        return {'success': false, 'message': 'Error: No hay sesión activa'};
      }

      // 🔧 CAMBIO: Verificar si la sesión está próxima a expirar
      final now = DateTime.now();
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        currentSession.expiresAt! * 1000,
      );
      final timeUntilExpiry = expiresAt.difference(now);

      Session sessionToSave;

      if (timeUntilExpiry.inMinutes < 5) {
        print(
          '🔄 [BIOMETRIC] Sesión próxima a expirar (${timeUntilExpiry.inMinutes} min), refrescando...',
        );
        try {
          final refreshResponse = await _supabase.auth.refreshSession(
            currentSession.refreshToken,
          );
          if (refreshResponse.session == null) {
            print('❌ [BIOMETRIC] No se pudo refrescar la sesión');
            return {
              'success': false,
              'message': 'Error: No se pudo refrescar la sesión',
            };
          }
          sessionToSave = refreshResponse.session!;
          print('✅ [BIOMETRIC] Sesión refrescada exitosamente');
        } catch (e) {
          print('❌ [BIOMETRIC] Error al refrescar sesión: $e');
          sessionToSave = currentSession;
        }
      } else {
        sessionToSave = currentSession;
        print(
          '✅ [BIOMETRIC] Sesión válida (expira en ${timeUntilExpiry.inMinutes} minutos)',
        );
      }

      // 🔧 CAMBIO CRÍTICO: Obtener device_id único
      final deviceId = await _getOrCreateDeviceId();

      // 🔧 CAMBIO: Guardar refresh_token + device_id + timestamp
      final credentialsData = {
        'refresh_token': sessionToSave.refreshToken,
        'device_id': deviceId,
        'user_id': sessionToSave.user.id,
        'expires_at': sessionToSave.expiresAt,
        'saved_at': DateTime.now().toIso8601String(),
      };

      await _secureStorage.write(
        key: _refreshTokenKey,
        value: jsonEncode(credentialsData),
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

      print('💾 [BIOMETRIC] Credenciales guardadas en secure storage');
      print('📱 [BIOMETRIC] Device ID: $deviceId');

      // 🔧 CAMBIO: Actualizar en la BD con device_id
      try {
        print(
          '🔄 [BIOMETRIC] Actualizando estado biométrico en la base de datos...',
        );
        await _supabase
            .from('users')
            .update({
              'biometric_enabled': true,
              'device_id': deviceId, // Guardamos el device_id en la BD
            })
            .eq('id', currentSession.user.id);

        print(
          '✅ [BIOMETRIC] Estado biométrico y device_id actualizados en la base de datos',
        );
      } catch (e) {
        print('⚠️ [BIOMETRIC] Error al actualizar la base de datos: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, true);

      await _auditService.logBiometricAction(currentSession.user.id, true);

      print('✅ [BIOMETRIC] Biometría habilitada exitosamente');
      return {'success': true, 'message': 'Acceso biométrico habilitado'};
    } catch (e) {
      print('❌ [BIOMETRIC] Error general: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Deshabilita el inicio de sesión biométrico.
  Future<Map<String, dynamic>> disableBiometricForCurrentUser() async {
    try {
      await _secureStorage.delete(
        key: _refreshTokenKey,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

      final currentSession = _supabase.auth.currentSession;
      if (currentSession != null) {
        try {
          print(
            '🔄 [BIOMETRIC] Deshabilitando biometría en la base de datos...',
          );
          await _supabase
              .from('users')
              .update({
                'biometric_enabled': false,
                'device_id': null, // 🔧 Limpiamos el device_id
              })
              .eq('id', currentSession.user.id);

          print(
            '✅ [BIOMETRIC] Estado biométrico deshabilitado en la base de datos',
          );
        } catch (e) {
          print('⚠️ [BIOMETRIC] Error al actualizar la base de datos: $e');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, false);

      if (currentSession != null) {
        await _auditService.logBiometricAction(currentSession.user.id, false);
      }

      return {'success': true, 'message': 'Acceso biométrico deshabilitado'};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Limpia solo las credenciales biométricas sin deshabilitar la biometría.
  Future<void> _clearBiometricCredentials() async {
    try {
      await _secureStorage.delete(
        key: _refreshTokenKey,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );
      print(
        '🧹 [BIOMETRIC] Credenciales limpiadas (biometría sigue habilitada)',
      );
    } catch (e) {
      print('❌ [BIOMETRIC] Error al limpiar credenciales: $e');
    }
  }

  /// 🔧 CORRECCIÓN: Renueva automáticamente las credenciales biométricas
  Future<void> _renewBiometricCredentials() async {
    try {
      print(
        '🔄 [RENEW] Iniciando renovación automática de credenciales biométricas...',
      );

      final currentSession = _supabase.auth.currentSession;
      if (currentSession == null) {
        print('❌ [RENEW] No hay sesión activa para renovar credenciales');
        return;
      }

      final now = DateTime.now();
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        currentSession.expiresAt! * 1000,
      );
      final timeUntilExpiry = expiresAt.difference(now);

      Session sessionToSave;

      if (timeUntilExpiry.inMinutes < 5) {
        print(
          '🔄 [RENEW] Sesión próxima a expirar (${timeUntilExpiry.inMinutes} min), refrescando...',
        );
        try {
          final refreshResponse = await _supabase.auth.refreshSession(
            currentSession.refreshToken,
          );
          if (refreshResponse.session?.refreshToken == null) {
            print('❌ [RENEW] No se pudo refrescar la sesión');
            sessionToSave = currentSession;
          } else {
            sessionToSave = refreshResponse.session!;
            print('✅ [RENEW] Sesión refrescada exitosamente');
          }
        } catch (e) {
          print('❌ [RENEW] Error al refrescar sesión: $e');
          sessionToSave = currentSession;
        }
      } else {
        sessionToSave = currentSession;
        print(
          '✅ [RENEW] Usando sesión actual (válida por ${timeUntilExpiry.inMinutes} minutos)',
        );
      }

      // 🔧 CAMBIO: Obtener/crear device_id
      final deviceId = await _getOrCreateDeviceId();

      // 🔧 CAMBIO: Guardar credenciales con device_id
      final credentialsData = {
        'refresh_token': sessionToSave.refreshToken,
        'device_id': deviceId,
        'user_id': sessionToSave.user.id,
        'expires_at': sessionToSave.expiresAt,
        'saved_at': DateTime.now().toIso8601String(),
      };

      await _secureStorage.write(
        key: _refreshTokenKey,
        value: jsonEncode(credentialsData),
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

      print('✅ [RENEW] Credenciales biométricas renovadas exitosamente');
      print('📱 [RENEW] Device ID: $deviceId');
    } catch (e) {
      print('❌ [RENEW] Error al renovar credenciales: $e');
    }
  }

  /// 🔧 CORRECCIÓN: Intenta iniciar sesión usando biometría
  Future<UserModel?> loginWithBiometrics() async {
    try {
      print('🔐 [LOGIN_BIOMETRIC] Iniciando login biométrico...');

      final isAuthenticated = await _biometricService.authenticate(
        'Inicia sesión con tu huella',
      );

      if (!isAuthenticated) {
        print('❌ [LOGIN_BIOMETRIC] Autenticación biométrica cancelada');
        return null;
      }

      print('✅ [LOGIN_BIOMETRIC] Autenticación biométrica exitosa');

      // 🔧 CAMBIO: Leer credenciales con device_id
      final credentialsJson = await _secureStorage.read(
        key: _refreshTokenKey,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

      if (credentialsJson == null) {
        print('❌ [LOGIN_BIOMETRIC] No se encontraron credenciales guardadas');
        throw BiometricAuthException(
          'CREDENTIALS_NOT_FOUND',
          'Credenciales biométricas no encontradas. Inicia sesión manualmente.',
        );
      }

      print('📱 [LOGIN_BIOMETRIC] Credenciales encontradas, parseando...');

      try {
        final credentialsData =
            jsonDecode(credentialsJson) as Map<String, dynamic>;
        final refreshToken = credentialsData['refresh_token'] as String?;
        final savedDeviceId = credentialsData['device_id'] as String?;
        final userId = credentialsData['user_id'] as String?;

        if (refreshToken == null) {
          print('❌ [LOGIN_BIOMETRIC] No hay refresh_token en las credenciales');
          throw BiometricAuthException(
            'INVALID_CREDENTIALS',
            'Credenciales biométricas inválidas. Inicia sesión manualmente.',
          );
        }

        // 🔧 VALIDACIÓN CRÍTICA: Verificar device_id
        final currentDeviceId = await _getOrCreateDeviceId();
        if (savedDeviceId != null && savedDeviceId != currentDeviceId) {
          print('⚠️ [LOGIN_BIOMETRIC] Device ID no coincide');
          print('   - Guardado: $savedDeviceId');
          print('   - Actual: $currentDeviceId');
          throw BiometricAuthException(
            'DEVICE_MISMATCH',
            'Este dispositivo no coincide con el registrado. Inicia sesión manualmente.',
          );
        }

        print(
          '🔄 [LOGIN_BIOMETRIC] Intentando refrescar sesión con refresh_token...',
        );

        final refreshResponse = await _supabase.auth.refreshSession(
          refreshToken,
        );

        if (refreshResponse.session != null) {
          print('✅ [LOGIN_BIOMETRIC] Sesión refrescada exitosamente');

          // 🔧 CAMBIO: Renovar credenciales con nueva sesión
          await _renewBiometricCredentials();

          final userProfile = await _getUserProfile(
            refreshResponse.session!.user.id,
          );
          print(
            '✅ [LOGIN_BIOMETRIC] Perfil de usuario obtenido: ${userProfile.email}',
          );

          return userProfile;
        } else {
          print('❌ [LOGIN_BIOMETRIC] No se pudo refrescar la sesión');
          await _clearBiometricCredentials();
          throw BiometricAuthException(
            'SESSION_EXPIRED',
            'Sesión biométrica expirada. Inicia sesión manualmente.',
          );
        }
      } catch (e) {
        print('❌ [LOGIN_BIOMETRIC] Error al procesar credenciales: $e');

        if (e is BiometricAuthException) {
          rethrow;
        }

        if (e.toString().contains('Invalid Refresh Token') ||
            e.toString().contains('refresh_token_not_found') ||
            e.toString().contains('JWT expired')) {
          print(
            '🧹 [LOGIN_BIOMETRIC] Token definitivamente expirado, limpiando credenciales...',
          );
          await _clearBiometricCredentials();
          throw BiometricAuthException(
            'CREDENTIALS_EXPIRED',
            'Credenciales biométricas expiradas. Inicia sesión manualmente.',
          );
        }

        throw BiometricAuthException(
          'AUTH_ERROR',
          'Error de autenticación. Intenta nuevamente o inicia sesión manualmente.',
        );
      }
    } on AuthException catch (e) {
      print('❌ [LOGIN_BIOMETRIC] Error AuthException: $e');

      if (e.message.contains('Invalid Refresh Token') ||
          e.message.contains('refresh_token_not_found') ||
          e.message.contains('JWT expired')) {
        print(
          '🧹 [LOGIN_BIOMETRIC] Refresh token definitivamente inválido, limpiando credenciales...',
        );
        await _clearBiometricCredentials();

        throw BiometricAuthException(
          'CREDENTIALS_EXPIRED',
          'Credenciales biométricas expiradas. Inicia sesión manualmente.',
        );
      }

      throw BiometricAuthException(
        'AUTH_ERROR',
        'Error de autenticación. Intenta nuevamente o inicia sesión manualmente.',
      );
    } catch (e) {
      print('❌ [LOGIN_BIOMETRIC] Error general: $e');
      rethrow;
    }
  }

  /// Verifica si la biometría está habilitada (solo revisa el indicador).
  Future<bool> checkBiometricStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// 🔧 CORRECCIÓN: Verifica si las credenciales biométricas son válidas
  Future<bool> areBiometricCredentialsValid() async {
    try {
      final credentialsJson = await _secureStorage.read(
        key: _refreshTokenKey,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

      if (credentialsJson == null) {
        print('🔍 [CREDENTIALS_CHECK] No hay credenciales guardadas');
        return false;
      }

      try {
        final credentialsData =
            jsonDecode(credentialsJson) as Map<String, dynamic>;
        final refreshToken = credentialsData['refresh_token'] as String?;
        final savedDeviceId = credentialsData['device_id'] as String?;
        final expiresAt = credentialsData['expires_at'] as int?;

        if (refreshToken == null) {
          print('🔍 [CREDENTIALS_CHECK] No hay refresh token');
          return false;
        }

        // 🔧 VALIDACIÓN: Verificar device_id
        final currentDeviceId = await _getOrCreateDeviceId();
        if (savedDeviceId != null && savedDeviceId != currentDeviceId) {
          print('🔍 [CREDENTIALS_CHECK] Device ID no coincide');
          return false;
        }

        // Verificar si la sesión no ha expirado
        if (expiresAt != null) {
          final expirationDate = DateTime.fromMillisecondsSinceEpoch(
            expiresAt * 1000,
          );
          final now = DateTime.now();

          if (now.difference(expirationDate).inDays > 30) {
            print(
              '🔍 [CREDENTIALS_CHECK] Credenciales muy antiguas (>30 días)',
            );
            return false;
          }
        }

        print('✅ [CREDENTIALS_CHECK] Credenciales válidas encontradas');
        return true;
      } catch (e) {
        print('❌ [CREDENTIALS_CHECK] Error al parsear credenciales: $e');
        return false;
      }
    } catch (e) {
      print('❌ [CREDENTIALS_CHECK] Error al verificar credenciales: $e');
      return false;
    }
  }
}
