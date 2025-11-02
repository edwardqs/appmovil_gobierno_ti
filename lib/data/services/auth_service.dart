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
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null) {
        return await _getUserProfile(user.id);
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
      final isAvailable = await _biometricService.hasBiometrics();
      if (!isAvailable) {
        return {'success': false, 'message': 'Biometría no disponible'};
      }

      final isAuthenticated = await _biometricService.authenticate(
        'Confirma tu identidad para habilitar el acceso rápido',
      );
      if (!isAuthenticated) {
        return {'success': false, 'message': 'Autenticación cancelada'};
      }

      final currentSession = _supabase.auth.currentSession;
      final refreshToken = currentSession?.refreshToken;

      if (refreshToken == null) {
        return {
          'success': false,
          'message': 'Error: No se encontró sesión activa',
        };
      }

      await _secureStorage.write(
        key: _refreshTokenKey,
        value: refreshToken,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, true);

      return {'success': true, 'message': 'Acceso biométrico habilitado'};
    } catch (e) {
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

  /// Intenta iniciar sesión usando biometría.
  Future<UserModel?> loginWithBiometrics() async {
    try {
      final isAuthenticated = await _biometricService.authenticate(
        'Inicia sesión con tu huella',
      );

      if (!isAuthenticated) {
        return null;
      }

      final refreshToken = await _secureStorage.read(
        key: _refreshTokenKey,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

      if (refreshToken == null) {
        // Solo deshabilitar si realmente no hay credenciales guardadas
        await disableBiometricForCurrentUser();
        throw BiometricAuthException(
          'CREDENTIALS_NOT_FOUND',
          'Credenciales biométricas no encontradas. Inicia sesión manualmente y vuelve a habilitarlas.',
        );
      }

      // refreshSession ya establece la sesión automáticamente
      final response = await _supabase.auth.refreshSession(refreshToken);

      if (response.session != null && response.user != null) {
        // Guardar el NUEVO refresh token para el próximo inicio de sesión
        final newRefreshToken = response.session!.refreshToken;
        if (newRefreshToken != null) {
          await _secureStorage.write(
            key: _refreshTokenKey,
            value: newRefreshToken,
            iOptions: _iosOptions,
            aOptions: _androidOptions,
          );
        }

        // Obtener el perfil del usuario
        return await _getUserProfile(response.user!.id);
      } else {
        // Sesión expirada, pero NO deshabilitar biometría
        throw BiometricAuthException(
          'SESSION_EXPIRED',
          'Tu sesión biométrica expiró. Por favor, inicia sesión manualmente.',
        );
      }
    } on AuthException catch (e) {
      debugPrint('Error en login biométrico (Auth): $e');
      // NO deshabilitar biometría por errores de sesión expirada
      throw BiometricAuthException(
        'SESSION_EXPIRED',
        'Tu sesión biométrica expiró. Por favor, inicia sesión manualmente.',
      );
    } catch (e) {
      debugPrint('Error en login biométrico (Otro): $e');
      if (e.toString().contains('Invalid Refresh Token')) {
        // NO deshabilitar biometría por token inválido, solo informar
        throw BiometricAuthException(
          'SESSION_EXPIRED',
          'Tu sesión biométrica expiró. Por favor, inicia sesión manualmente.',
        );
      }
      rethrow;
    }
  }

  /// Verifica si la biometría está habilitada (solo revisa el indicador).
  Future<bool> checkBiometricStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }
}
