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

  static const String _refreshTokenKey = 'supabase_refresh_token';
  static const String _biometricEnabledKey = 'biometric_enabled';

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
        
        print('👤 [LOGIN_EMAIL] Perfil obtenido. Biometría habilitada: ${userProfile.biometricEnabled}');
        
        // Registrar login exitoso en auditoría
        await _auditService.logLoginAttempt(email, success: true);
        
        // Si el usuario tenía biometría habilitada, renovar automáticamente las credenciales
        if (userProfile.biometricEnabled) {
          print('🔄 [LOGIN_EMAIL] Iniciando renovación automática de credenciales biométricas...');
          await _renewBiometricCredentials();
          print('✅ [LOGIN_EMAIL] Renovación de credenciales completada');
        }
        
        return userProfile;
      } else {
        await _auditService.logLoginAttempt(email, success: false, error: 'Usuario no encontrado');
        throw Exception('Usuario no encontrado');
      }
    } on AuthException catch (e) {
      await _auditService.logLoginAttempt(email, success: false, error: e.message);
      throw Exception('Error de autenticación: ${e.message}');
    } catch (e) {
      await _auditService.logLoginAttempt(email, success: false, error: e.toString());
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
      
      // Usar consulta directa en lugar de RPC para evitar problemas de políticas RLS
      final response = await _supabase
          .from('users')
          .select('id, name, email, role, dni, phone, address, biometric_enabled')
          .eq('id', userId)
          .single();

      print('🔍 [PROFILE] Respuesta de la consulta: $response');
      print('🔍 [PROFILE] Rol obtenido de la BD: ${response['role']}');

      if (response != null) {
        final biometricEnabled = response['biometric_enabled'] ?? false;
        final roleFromDB = response['role'];
        final convertedRole = UserModel.roleFromString(roleFromDB);
        
        print('🔍 [PROFILE] Usuario: ${response['email']}, biometricEnabled desde DB: $biometricEnabled');
        print('🔍 [PROFILE] Rol desde BD: "$roleFromDB" -> Convertido a: $convertedRole');

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
      
      // Manejo específico para errores de RLS
      if (e.toString().contains('row-level security policy') || 
          e.toString().contains('infinite recursion detected')) {
        print('⚠️ [PROFILE] Error de política RLS detectado - usando datos básicos del usuario Auth');
        print('   Para corregir permanentemente: Ejecutar supabase_users_rls_fix.sql en Supabase SQL Editor');
        
        // Fallback: usar datos básicos del usuario de Auth
        final currentUser = _supabase.auth.currentUser;
        if (currentUser != null && currentUser.id == userId) {
          // Intentar obtener el rol del JWT token primero
          String? roleFromJWT;
          try {
            final session = _supabase.auth.currentSession;
            if (session != null) {
              // Decodificar el JWT para obtener el rol
              final payload = session.accessToken.split('.')[1];
              final normalizedPayload = base64Url.normalize(payload);
              final decodedPayload = utf8.decode(base64Url.decode(normalizedPayload));
              final Map<String, dynamic> jwtData = json.decode(decodedPayload);
              roleFromJWT = jwtData['role'] as String?;
              print('🔍 [PROFILE] Rol obtenido del JWT: $roleFromJWT');
            }
          } catch (jwtError) {
            print('⚠️ [PROFILE] Error al decodificar JWT: $jwtError');
          }
          
          // Usar el rol del JWT si está disponible, sino usar metadatos, sino usar default
          final userRole = roleFromJWT ?? 
                          currentUser.userMetadata?['role'] ?? 
                          'auditor_junior';
          
          print('🔍 [PROFILE] Rol final asignado: $userRole');
          
          return UserModel(
            id: currentUser.id,
            name: currentUser.userMetadata?['name'] ?? 'Usuario',
            email: currentUser.email ?? '',
            role: UserModel.roleFromString(userRole),
            biometricEnabled: false, // Por defecto false hasta que se pueda consultar la DB
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
  // FLUJO BIOMÉTRICO SEGURO
  // =======================================================================

  /// Habilita el inicio de sesión biométrico
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

      // Verificar que hay una sesión activa
      final currentSession = _supabase.auth.currentSession;
      if (currentSession == null) {
        print('❌ [BIOMETRIC] No hay sesión activa');
        return {
          'success': false,
          'message': 'Error: No hay sesión activa',
        };
      }

      // Verificar si la sesión está próxima a expirar (menos de 2 minutos)
      final now = DateTime.now();
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(currentSession.expiresAt! * 1000);
      final timeUntilExpiry = expiresAt.difference(now);

      print('⏰ [BIOMETRIC] Sesión expira en: ${timeUntilExpiry.inMinutes} minutos');
      print('📅 [BIOMETRIC] Expira el: $expiresAt');
      print('🕐 [BIOMETRIC] Ahora es: $now');

      Session sessionToSave;

      if (timeUntilExpiry.inMinutes < 2) {
        print('🔄 [BIOMETRIC] Sesión próxima a expirar, refrescando...');
        // Si la sesión expira pronto, refrescarla primero
        try {
          final refreshResponse = await _supabase.auth.refreshSession(currentSession.refreshToken);
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
          // Si no se puede refrescar, usar la sesión actual de todos modos
          sessionToSave = currentSession;
          print('⚠️ [BIOMETRIC] Usando sesión actual a pesar del error de refresh');
        }
      } else {
        // La sesión es válida, usar la sesión actual
        sessionToSave = currentSession;
        print('✅ [BIOMETRIC] Usando sesión actual (sesión válida)');
      }

      // Guardar la sesión completa como JSON
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: jsonEncode(sessionToSave.toJson()),
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

      print('💾 [BIOMETRIC] Sesión guardada en secure storage');

      // Actualizar el estado biométrico en la base de datos
      try {
        print('🔄 [BIOMETRIC] Actualizando estado biométrico en la base de datos...');
        await _supabase
            .from('users')
            .update({'biometric_enabled': true})
            .eq('id', currentSession.user.id);
        
        print('✅ [BIOMETRIC] Estado biométrico actualizado en la base de datos');
      } catch (e) {
        print('⚠️ [BIOMETRIC] Error al actualizar la base de datos: $e');
        // No fallar completamente, las credenciales locales están guardadas
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, true);

      // Registrar habilitación de biometría en auditoría
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

      // Actualizar el estado biométrico en la base de datos
       final currentSession = _supabase.auth.currentSession;
       if (currentSession != null) {
         try {
           print('🔄 [BIOMETRIC] Deshabilitando biometría en la base de datos...');
           await _supabase
               .from('users')
               .update({'biometric_enabled': false})
               .eq('id', currentSession.user.id);
           
           print('✅ [BIOMETRIC] Estado biométrico deshabilitado en la base de datos');
         } catch (e) {
           print('⚠️ [BIOMETRIC] Error al actualizar la base de datos: $e');
         }
       }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, false);

      // Registrar deshabilitación de biometría en auditoría
      if (currentSession != null) {
        await _auditService.logBiometricAction(currentSession.user.id, false);
      }

      return {'success': true, 'message': 'Acceso biométrico deshabilitado'};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Limpia solo las credenciales biométricas sin deshabilitar la biometría.
  /// Esto permite que el usuario mantenga su preferencia de biometría habilitada.
  Future<void> _clearBiometricCredentials() async {
    try {
      // Limpiar la sesión JSON guardada
      await _secureStorage.delete(
        key: _refreshTokenKey,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );
      
      // Limpiar también la clave del access token (por si había formato anterior)
      await _secureStorage.delete(
        key: '${_refreshTokenKey}_access',
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );
      
      print('🧹 [BIOMETRIC] Credenciales limpiadas (biometría sigue habilitada)');
    } catch (e) {
      print('❌ [BIOMETRIC] Error al limpiar credenciales: $e');
    }
  }

  /// Renueva automáticamente las credenciales biométricas sin solicitar autenticación biométrica.
  /// Se usa cuando el usuario hace login manual y ya tenía biometría habilitada.
  Future<void> _renewBiometricCredentials() async {
    try {
      print('🔄 [RENEW] Iniciando renovación automática de credenciales biométricas...');
      print('🔄 [BIOMETRIC] Renovando credenciales biométricas automáticamente...');
      
      // Verificar que hay una sesión activa
      final currentSession = _supabase.auth.currentSession;
      if (currentSession == null) {
        print('❌ [BIOMETRIC] No hay sesión activa para renovar credenciales');
        return;
      }

      // Verificar si la sesión está próxima a expirar (menos de 2 minutos)
      final now = DateTime.now();
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(currentSession.expiresAt! * 1000);
      final timeUntilExpiry = expiresAt.difference(now);

      Session sessionToSave;

      if (timeUntilExpiry.inMinutes < 2) {
        print('🔄 [BIOMETRIC] Sesión próxima a expirar, refrescando...');
        try {
          final refreshResponse = await _supabase.auth.refreshSession(currentSession.refreshToken);
          if (refreshResponse.session?.refreshToken == null) {
            print('❌ [BIOMETRIC] No se pudo refrescar la sesión, usando sesión actual');
            sessionToSave = currentSession;
          } else {
            sessionToSave = refreshResponse.session!;
            print('✅ [BIOMETRIC] Sesión refrescada exitosamente');
          }
        } catch (e) {
          print('❌ [BIOMETRIC] Error al refrescar sesión, usando sesión actual: $e');
          sessionToSave = currentSession;
        }
      } else {
        // La sesión es válida, usar la sesión actual
        sessionToSave = currentSession;
        print('✅ [BIOMETRIC] Usando sesión actual (sesión válida)');
      }

      // Guardar la sesión completa en formato JSON (igual que enableBiometricForCurrentUser)
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: jsonEncode(sessionToSave.toJson()),
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

      print('✅ [BIOMETRIC] Credenciales biométricas renovadas exitosamente');
      print('🎉 [RENEW] Renovación automática completada con éxito');
    } catch (e) {
      print('❌ [BIOMETRIC] Error al renovar credenciales: $e');
      print('💥 [RENEW] Error en renovación automática: $e');
    }
  }

  /// Intenta iniciar sesión usando biometría.
  Future<UserModel?> loginWithBiometrics() async {
    try {
      print('🔐 [LOGIN_BIOMETRIC] Iniciando login biométrico...');
      print('🔐 [AUTH_SERVICE] Llamando a _biometricService.authenticate()...');
      
      final isAuthenticated = await _biometricService.authenticate(
        'Inicia sesión con tu huella',
      );

      print('🔐 [AUTH_SERVICE] Resultado de autenticación biométrica: $isAuthenticated');

      if (!isAuthenticated) {
        print('❌ [LOGIN_BIOMETRIC] Autenticación biométrica cancelada');
        print('🚫 [AUTH_SERVICE] Autenticación biométrica falló o fue cancelada');
        return null;
      }

      print('✅ [LOGIN_BIOMETRIC] Autenticación biométrica exitosa');
      print('🔐 [AUTH_SERVICE] Recuperando sesión desde secure storage...');

      // Leer la sesión JSON guardada
      final sessionJson = await _secureStorage.read(
        key: _refreshTokenKey,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

      if (sessionJson == null) {
        print('❌ [LOGIN_BIOMETRIC] No se encontró sesión guardada');
        print('❌ [AUTH_SERVICE] No hay datos de sesión guardados');
        throw BiometricAuthException(
          'CREDENTIALS_NOT_FOUND',
          'Credenciales biométricas no encontradas. Inicia sesión manualmente para renovar las credenciales.',
        );
      }

      print('📱 [LOGIN_BIOMETRIC] Sesión encontrada, intentando recuperar sesión...');
      print('🔐 [AUTH_SERVICE] Datos de sesión encontrados, parseando...');

      try {
        // Intentar recuperar la sesión primero
        print('🔐 [AUTH_SERVICE] Recuperando sesión en Supabase...');
        final response = await _supabase.auth.recoverSession(sessionJson);

        print('🔄 [LOGIN_BIOMETRIC] Respuesta de recoverSession: ${response.session != null ? 'Sesión recuperada' : 'Sin sesión'}');

        if (response.session != null) {
          print('✅ [LOGIN_BIOMETRIC] Sesión recuperada exitosamente');
          print('✅ [AUTH_SERVICE] Sesión recuperada exitosamente: ${response.session!.user.email}');
          
          // Guardar la nueva sesión actualizada
          print('🔄 [LOGIN_BIOMETRIC] Guardando nueva sesión...');
          await _secureStorage.write(
            key: _refreshTokenKey, 
            value: jsonEncode(response.session!.toJson()),
            iOptions: _iosOptions,
            aOptions: _androidOptions,
          );
          
          // Obtener el perfil del usuario
          final userProfile = await _getUserProfile(response.session!.user.id);
          print('👤 [LOGIN_BIOMETRIC] Perfil de usuario obtenido: ${userProfile.email}');
          print('✅ [AUTH_SERVICE] Perfil de usuario obtenido: ${userProfile.email}');
          
          return userProfile;
        } else {
          print('⚠️ [LOGIN_BIOMETRIC] No se pudo recuperar sesión, intentando con refresh token...');
          print('❌ [AUTH_SERVICE] No se pudo recuperar la sesión del usuario');
          
          // Si no se puede recuperar la sesión, intentar usar solo el refresh token
          final sessionData = jsonDecode(sessionJson);
          final refreshToken = sessionData['refresh_token'];
          
          if (refreshToken != null) {
            print('🔄 [LOGIN_BIOMETRIC] Intentando refrescar sesión con refresh token...');
            
            try {
              final refreshResponse = await _supabase.auth.refreshSession(refreshToken);
              
              if (refreshResponse.session != null) {
                print('✅ [LOGIN_BIOMETRIC] Sesión refrescada exitosamente');
                
                // Guardar la nueva sesión
                await _secureStorage.write(
                  key: _refreshTokenKey, 
                  value: jsonEncode(refreshResponse.session!.toJson()),
                  iOptions: _iosOptions,
                  aOptions: _androidOptions,
                );
                
                // Obtener el perfil del usuario
                final userProfile = await _getUserProfile(refreshResponse.session!.user.id);
                print('👤 [LOGIN_BIOMETRIC] Perfil de usuario obtenido tras refresh: ${userProfile.email}');
                print('✅ [AUTH_SERVICE] Perfil de usuario obtenido tras refresh: ${userProfile.email}');
                
                return userProfile;
              }
            } catch (refreshError) {
              print('❌ [LOGIN_BIOMETRIC] Error al refrescar con refresh token: $refreshError');
            }
          }
          
          throw BiometricAuthException(
            'SESSION_EXPIRED',
            'Sesión biométrica expirada. Inicia sesión manualmente para renovar las credenciales.'
          );
        }
      } catch (e) {
        print('❌ [LOGIN_BIOMETRIC] Error al establecer sesión: $e');
        
        // Solo limpiar credenciales si es un error irrecuperable
        if (e.toString().contains('Invalid Refresh Token') || 
            e.toString().contains('refresh_token_not_found') ||
            e.toString().contains('JWT expired')) {
          print('🧹 [LOGIN_BIOMETRIC] Token definitivamente expirado, limpiando credenciales...');
          await _clearBiometricCredentials();
        }
        
        throw BiometricAuthException(
          'INVALID_SESSION',
          'Sesión biométrica inválida. Inicia sesión manualmente para renovar las credenciales.'
        );
      }
    } on AuthException catch (e) {
      print('❌ [LOGIN_BIOMETRIC] Error AuthException: $e');
      
      // Manejar específicamente errores de tokens expirados
      if (e.message.contains('Invalid Refresh Token') || 
          e.message.contains('refresh_token_not_found') ||
          e.message.contains('JWT expired')) {
        print('🧹 [LOGIN_BIOMETRIC] Refresh token definitivamente inválido, limpiando credenciales...');
        await _clearBiometricCredentials();
        
        throw BiometricAuthException(
          'CREDENTIALS_EXPIRED',
          'Tus credenciales biométricas han expirado. Inicia sesión manualmente para renovar las credenciales.',
        );
      }
      
      // Para otros errores de autenticación, no limpiar credenciales inmediatamente
      throw BiometricAuthException(
        'AUTH_ERROR',
        'Error de autenticación. Intenta nuevamente o inicia sesión manualmente.',
      );
    } catch (e) {
      print('❌ [LOGIN_BIOMETRIC] Error general: $e');
      print('❌ [AUTH_SERVICE] Error en loginWithBiometrics: $e');
      debugPrint('Error en login biométrico (Otro): $e');
      rethrow;
    }
  }

  /// Verifica si la biometría está habilitada (solo revisa el indicador).
  Future<bool> checkBiometricStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// Verifica si las credenciales biométricas están disponibles y son válidas.
  /// Retorna true si las credenciales existen, false si no existen o son inválidas.
  Future<bool> areBiometricCredentialsValid() async {
    try {
      final sessionJson = await _secureStorage.read(
        key: _refreshTokenKey,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

      if (sessionJson == null) {
        print('🔍 [CREDENTIALS_CHECK] No hay credenciales guardadas');
        return false;
      }

      // Intentar parsear la sesión para verificar que es válida
      try {
        final sessionData = jsonDecode(sessionJson);
        final refreshToken = sessionData['refresh_token'];
        final expiresAt = sessionData['expires_at'];
        
        if (refreshToken == null) {
          print('🔍 [CREDENTIALS_CHECK] No hay refresh token en las credenciales');
          return false;
        }

        // Verificar si la sesión no ha expirado completamente
        if (expiresAt != null) {
          final expirationDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
          final now = DateTime.now();
          
          // Si la sesión expiró hace más de 30 días, considerarla inválida
          if (now.difference(expirationDate).inDays > 30) {
            print('🔍 [CREDENTIALS_CHECK] Credenciales muy antiguas (>30 días)');
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
