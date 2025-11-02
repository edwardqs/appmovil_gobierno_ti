import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_gobiernoti/data/models/user_model.dart';
import 'package:app_gobiernoti/data/services/biometric_service.dart';
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
        
        // Si el usuario tenía biometría habilitada, renovar automáticamente las credenciales
        if (userProfile.biometricEnabled) {
          print('🔄 [LOGIN_EMAIL] Iniciando renovación automática de credenciales biométricas...');
          await _renewBiometricCredentials();
          print('✅ [LOGIN_EMAIL] Renovación de credenciales completada');
        }
        
        return userProfile;
      } else {
        throw Exception('Usuario no encontrado');
      }
    } on AuthException catch (e) {
      throw Exception('Error de autenticación: ${e.message}');
    } catch (e) {
      throw Exception('Error desconocido: ${e.toString()}');
    }
  }

  /// Cierra la sesión del usuario.
  Future<void> signOut() async {
    await _supabase.auth.signOut(scope: SignOutScope.local);
  }

  /// Obtiene el perfil de usuario desde la RPC de Supabase.
  Future<UserModel> _getUserProfile(String userId) async {
    try {
      final response = await _supabase.rpc(
        'get_user_profile',
        params: {'p_user_id': userId},
      );

      if (response != null && response['success'] == true) {
        final userData = response['user'];
        final prefs = await SharedPreferences.getInstance();
        final biometricEnabled = prefs.getBool(_biometricEnabledKey) ?? false;

        return UserModel(
          id: userData['id'],
          name: userData['name'],
          email: userData['email'],
          role: UserModel.roleFromString(userData['role']),
          biometricEnabled: biometricEnabled,
          dni: userData['dni'],
          phone: userData['phone'],
          address: userData['address'],
        );
      } else {
        throw Exception(
          response?['message'] ?? 'Error al obtener el perfil del usuario',
        );
      }
    } catch (e) {
      throw Exception('Error en RPC get_user_profile: ${e.toString()}');
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

      // Verificar si la sesión está próxima a expirar (menos de 5 minutos)
      final now = DateTime.now();
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(currentSession.expiresAt! * 1000);
      final timeUntilExpiry = expiresAt.difference(now);

      print('⏰ [BIOMETRIC] Sesión expira en: ${timeUntilExpiry.inMinutes} minutos');
      print('📅 [BIOMETRIC] Expira el: $expiresAt');
      print('🕐 [BIOMETRIC] Ahora es: $now');

      String refreshTokenToSave;

      if (timeUntilExpiry.inMinutes < 5) {
        print('🔄 [BIOMETRIC] Sesión próxima a expirar, refrescando...');
        // Si la sesión expira pronto, refrescarla primero
        try {
          final refreshResponse = await _supabase.auth.refreshSession(currentSession.refreshToken);
          if (refreshResponse.session?.refreshToken == null) {
            print('❌ [BIOMETRIC] No se pudo refrescar la sesión');
            return {
              'success': false,
              'message': 'Error: No se pudo refrescar la sesión',
            };
          }
          refreshTokenToSave = refreshResponse.session!.refreshToken!;
          print('✅ [BIOMETRIC] Sesión refrescada exitosamente');
        } catch (e) {
          print('❌ [BIOMETRIC] Error al refrescar sesión: $e');
          return {
            'success': false,
            'message': 'Error al refrescar sesión: ${e.toString()}',
          };
        }
      } else {
        // La sesión es válida, usar el refresh token actual
        refreshTokenToSave = currentSession.refreshToken!;
        print('✅ [BIOMETRIC] Usando refresh token actual (sesión válida)');
      }

      // Guardar el refresh token válido
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: refreshTokenToSave,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

      print('💾 [BIOMETRIC] Refresh token guardado en secure storage');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, true);

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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, false);

      return {'success': true, 'message': 'Acceso biométrico deshabilitado'};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Limpia solo las credenciales biométricas sin deshabilitar la biometría.
  /// Esto permite que el usuario mantenga su preferencia de biometría habilitada.
  Future<void> _clearBiometricCredentials() async {
    try {
      await _secureStorage.delete(
        key: _refreshTokenKey,
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

      // Verificar si la sesión está próxima a expirar (menos de 5 minutos)
      final now = DateTime.now();
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(currentSession.expiresAt! * 1000);
      final timeUntilExpiry = expiresAt.difference(now);

      String refreshTokenToSave;

      if (timeUntilExpiry.inMinutes < 5) {
        print('🔄 [BIOMETRIC] Sesión próxima a expirar, refrescando...');
        try {
          final refreshResponse = await _supabase.auth.refreshSession(currentSession.refreshToken);
          if (refreshResponse.session?.refreshToken == null) {
            print('❌ [BIOMETRIC] No se pudo refrescar la sesión');
            return;
          }
          refreshTokenToSave = refreshResponse.session!.refreshToken!;
          print('✅ [BIOMETRIC] Sesión refrescada exitosamente');
        } catch (e) {
          print('❌ [BIOMETRIC] Error al refrescar sesión: $e');
          return;
        }
      } else {
        // La sesión es válida, usar el refresh token actual
        refreshTokenToSave = currentSession.refreshToken!;
        print('✅ [BIOMETRIC] Usando refresh token actual (sesión válida)');
      }

      // Guardar el refresh token válido
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: refreshTokenToSave,
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
      
      final isAuthenticated = await _biometricService.authenticate(
        'Inicia sesión con tu huella',
      );

      if (!isAuthenticated) {
        print('❌ [LOGIN_BIOMETRIC] Autenticación biométrica cancelada');
        return null;
      }

      print('✅ [LOGIN_BIOMETRIC] Autenticación biométrica exitosa');

      final refreshToken = await _secureStorage.read(
        key: _refreshTokenKey,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

      if (refreshToken == null) {
        print('❌ [LOGIN_BIOMETRIC] No se encontró refresh token guardado');
        // Solo limpiar credenciales, mantener biometría habilitada para que el usuario no tenga que reconfigurarla
        await _clearBiometricCredentials();
        throw BiometricAuthException(
          'CREDENTIALS_NOT_FOUND',
          'Credenciales biométricas no encontradas. Inicia sesión manualmente para renovar las credenciales.',
        );
      }

      print('📱 [LOGIN_BIOMETRIC] Refresh token encontrado, intentando establecer sesión...');

      // Usar setSession en lugar de refreshSession para establecer una sesión completa
      final response = await _supabase.auth.setSession(refreshToken);

      print('🔄 [LOGIN_BIOMETRIC] Respuesta de setSession: ${response.session != null ? 'Sesión establecida' : 'Sin sesión'}');

      if (response.session != null) {
        print('✅ [LOGIN_BIOMETRIC] Sesión establecida exitosamente');
        
        // Guardar el nuevo refresh token si es diferente
        final newRefreshToken = response.session!.refreshToken;
        if (newRefreshToken != null && newRefreshToken != refreshToken) {
          print('🔄 [LOGIN_BIOMETRIC] Guardando nuevo refresh token...');
          await _secureStorage.write(
            key: _refreshTokenKey, 
            value: newRefreshToken,
            iOptions: _iosOptions,
            aOptions: _androidOptions,
          );
        }
        
        // Obtener el perfil del usuario
        final userProfile = await _getUserProfile(response.session!.user.id);
        print('👤 [LOGIN_BIOMETRIC] Perfil de usuario obtenido: ${userProfile.email}');
        
        return userProfile;
      } else {
        print('❌ [LOGIN_BIOMETRIC] No se pudo establecer sesión válida');
        throw BiometricAuthException(
          'SESSION_EXPIRED',
          'Sesión biométrica expirada'
        );
      }
    } on AuthException catch (e) {
      print('❌ [LOGIN_BIOMETRIC] Error AuthException: $e');
      
      // Manejar específicamente el error de refresh token inválido
      if (e.message.contains('Invalid Refresh Token') || 
          e.message.contains('refresh_token_not_found')) {
        print('🔄 [LOGIN_BIOMETRIC] Refresh token inválido, limpiando credenciales...');
        
        // Limpiar solo las credenciales, mantener biometría habilitada
        await _clearBiometricCredentials();
        
        throw BiometricAuthException(
          'CREDENTIALS_EXPIRED',
          'Tus credenciales biométricas han expirado. Inicia sesión manualmente para renovar las credenciales.',
        );
      }
      
      // Para otros errores de autenticación
      throw BiometricAuthException(
        'SESSION_EXPIRED',
        'Tu sesión biométrica expiró. Por favor, inicia sesión manualmente.',
      );
    } catch (e) {
      print('❌ [LOGIN_BIOMETRIC] Error general: $e');
      debugPrint('Error en login biométrico (Otro): $e');
      rethrow;
    }
  }

  /// Verifica si la biometría está habilitada (solo revisa el indicador).
  Future<bool> checkBiometricStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }
}
