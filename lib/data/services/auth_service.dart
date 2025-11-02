import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Importar
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_gobiernoti/data/models/user_model.dart';
import 'package:app_gobiernoti/data/services/biometric_service.dart';
import 'package:app_gobiernoti/core/locator.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final BiometricService _biometricService = locator<BiometricService>();

  // Usar flutter_secure_storage para guardar credenciales de forma segura
  final _secureStorage = const FlutterSecureStorage();

  // Opciones para asegurar que los datos estén encriptados
  // y solo sean accesibles después del primer desbloqueo del dispositivo.
  IOSOptions get _iosOptions => const IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );
  AndroidOptions get _androidOptions =>
      const AndroidOptions(encryptedSharedPreferences: true);

  // Clave para guardar el token de refresco
  static const String _refreshTokenKey = 'supabase_refresh_token';
  // Clave para guardar el indicador en SharedPreferences (no seguro)
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
        // Almacena la sesión actual para uso futuro (como restaurar sesión)
        // Esto es opcional pero recomendado si quieres persistencia entre reinicios de app
        // (Supabase puede manejar esto automáticamente si usaste `Supabase.initialize`)

        // Lo más importante: obtener el perfil del usuario desde tu RPC
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
    await _supabase.auth.signOut();
    // Opcionalmente, también podrías limpiar los datos biométricos aquí
    // si quieres que el logout también deshabilite la huella.
    // await disableBiometricForCurrentUser();
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
          biometricEnabled: biometricEnabled, // Usar el indicador de prefs
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
      // 1. Crear el usuario en Supabase Auth
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('No se pudo crear el usuario en Auth.');
      }

      // 2. Llamar al RPC para crear el perfil en la tabla 'users'
      final profileResponse = await _supabase.rpc(
        'register_user', // Tu RPC existente
        params: {
          'p_user_id': user.id,
          'p_email': email,
          'p_name': name,
          'p_role': role,
          'p_dni': dni,
          'p_phone': phone,
          'p_address': address,
          // Eliminamos todos los parámetros de biometría
        },
      );

      if (profileResponse != null && profileResponse['success'] == true) {
        // 3. Devolver el modelo de usuario completo
        return UserModel(
          id: user.id,
          name: name,
          email: email,
          role: UserModel.roleFromString(role),
          biometricEnabled: false, // Nuevo usuario, biometría deshabilitada
          dni: dni,
          phone: phone,
          address: address,
        );
      } else {
        // Si falla el RPC, eliminar el usuario de Auth para consistencia
        // NOTA: Necesitas habilitar los permisos de Admin para esto
        // await _supabase.auth.admin.deleteUser(user.id);
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
  // NUEVO FLUJO BIOMÉTRICO SEGURO
  // =======================================================================

  /// Habilita el inicio de sesión biométrico para el usuario actual.
  /// Guarda el token de refresco de la sesión actual en almacenamiento seguro.
  Future<Map<String, dynamic>> enableBiometricForCurrentUser() async {
    try {
      // 1. Verificar si la biometría está disponible en el dispositivo
      final isAvailable = await _biometricService.hasBiometrics();
      if (!isAvailable) {
        return {'success': false, 'message': 'Biometría no disponible'};
      }

      // 2. Pedir la huella/rostro para confirmar la acción
      final isAuthenticated = await _biometricService.authenticate(
        'Confirma tu identidad para habilitar el acceso rápido',
      );
      if (!isAuthenticated) {
        return {'success': false, 'message': 'Autenticación cancelada'};
      }

      // 3. Obtener el token de refresco de la sesión activa de Supabase
      final currentSession = _supabase.auth.currentSession;
      final refreshToken = currentSession?.refreshToken;

      if (refreshToken == null) {
        return {
          'success': false,
          'message': 'Error: No se encontró sesión activa',
        };
      }

      // 4. Guardar el token de refresco en Almacenamiento Seguro
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: refreshToken,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

      // 5. Guardar un indicador simple en SharedPreferences (no seguro)
      //    para mostrar/ocultar el botón de huella en la UI.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, true);

      return {'success': true, 'message': 'Acceso biométrico habilitado'};
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Deshabilita el inicio de sesión biométrico.
  /// Elimina el token de refresco del almacenamiento seguro.
  Future<Map<String, dynamic>> disableBiometricForCurrentUser() async {
    try {
      // 1. Borrar la clave del almacenamiento seguro
      await _secureStorage.delete(
        key: _refreshTokenKey,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

      // 2. Borrar el indicador de SharedPreferences
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
      // 1. Pedir la huella/rostro al usuario
      final isAuthenticated = await _biometricService.authenticate(
        'Inicia sesión con tu huella',
      );

      if (!isAuthenticated) {
        return null; // El usuario canceló la autenticación
      }

      // 2. Si tiene éxito, leer el token de refresco del almacenamiento seguro
      final refreshToken = await _secureStorage.read(
        key: _refreshTokenKey,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

      if (refreshToken == null) {
        // Esto puede pasar si el usuario elimina la huella de su dispositivo
        // o si los datos seguros se corrompen.
        await disableBiometricForCurrentUser(); // Limpiar el estado
        throw Exception(
          'Credenciales biométricas no encontradas. Inicia sesión manualmente y vuelve a habilitarlas.',
        );
      }

      // 3. Usar el token de refresco para restaurar la sesión de Supabase
      final response = await _supabase.auth.refreshSession(refreshToken);

      if (response.user != null) {
        // 4. Si la sesión se restaura, obtener el perfil del usuario
        return await _getUserProfile(response.user!.id);
      } else {
        throw Exception(
          'No se pudo restaurar la sesión con el token guardado.',
        );
      }
    } catch (e) {
      debugPrint('Error en login biométrico: $e');
      rethrow; // Lanzar la excepción para que el AuthProvider la maneje
    }
  }

  /// Verifica si la biometría está habilitada (solo revisa el indicador).
  /// Esto se usa para que AuthProvider sepa si mostrar el botón de huella.
  Future<bool> checkBiometricStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  // --- MÉTODOS ANTIGUOS ELIMINADOS ---
  // Se eliminaron:
  // - _generateDeviceId
  // - _generateBiometricHash
  // - saveBiometricData
  // - _getBiometricData
  // - clearBiometricData
  // - (Tu método enableBiometricForCurrentUser original)
  // - (Tu método registerUserWithBiometrics original)
}
