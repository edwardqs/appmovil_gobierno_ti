import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

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

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  /// Obtiene el usuario actual desde la sesión
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
      print('Error al obtener usuario actual: $e');
      return null;
   }
  }
  
  /// Registra un nuevo usuario - VERSIÓN CORREGIDA

  /// Inicia sesión con email y contraseña
  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw AuthServiceException('LOGIN_FAILED', 'No se pudo iniciar sesión');
      }

      final userData = await _supabase
          .from('users')
          .select()
          .eq('id', response.user!.id)
          .single();

      return UserModel(
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
    } on AuthException catch (e) {
      throw AuthServiceException('AUTH_ERROR', e.message);
    } catch (e) {
      throw AuthServiceException('UNKNOWN_ERROR', e.toString());
    }
  }

  /// Método para autenticación biométrica
  Future<UserModel?> loginWithBiometrics() async {
    try {
      // Implementación de autenticación biométrica
      // Este es un método simulado que deberías implementar según tus necesidades
      final currentUser = await getCurrentUser();
      return currentUser;
    } catch (e) {
      throw AuthServiceException('BIOMETRIC_ERROR', 'Error en autenticación biométrica: ${e.toString()}');
    }
  }
  
  /// Cierra la sesión del usuario
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  /// Verifica si hay datos biométricos guardados
  Future<bool> hasBiometricData() async {
    try {
      // Implementación para verificar datos biométricos
      // Este es un método simulado que deberías implementar según tus necesidades
      return false;
    } catch (e) {
      return false;
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
      print('📝 [REGISTER] Email: $email');
      print('📝 [REGISTER] Nombre: $name');
      print('📝 [REGISTER] Rol solicitado: $role');
      print('📝 [REGISTER] DNI: ${dni ?? "No proporcionado"}');

      // PASO 1: Crear usuario en auth.users
      print('🔐 [REGISTER] Creando usuario en auth.users...');
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        print('❌ [REGISTER] No se pudo crear el usuario en Auth');
        throw AuthServiceException(
          'USER_CREATION_FAILED',
          'No se pudo crear el usuario en el sistema de autenticación.',
        );
      }

      print('✅ [REGISTER] Usuario creado en auth.users con ID: ${user.id}');
      print(
        '📧 [REGISTER] Email de confirmación enviado: ${response.session == null}',
      );

      // PASO 2: Crear perfil en public.users usando RPC
      print('🔄 [REGISTER] Creando perfil en public.users...');

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

        print('📦 [REGISTER] Respuesta de register_user: $profileResponse');

        // Validar respuesta
        if (profileResponse == null) {
          print('❌ [REGISTER] La función register_user retornó null');
          throw UserProfileException(
            'PROFILE_CREATION_FAILED',
            'No se recibió respuesta al crear el perfil de usuario.',
          );
        }

        // Parsear respuesta JSON
        final result = profileResponse as Map<String, dynamic>;
        final success = result['success'] as bool? ?? false;
        final message = result['message'] as String? ?? 'Error desconocido';

        if (!success) {
          print('❌ [REGISTER] Error al crear perfil: $message');

          // Si el perfil falló pero el usuario de Auth se creó, intentar eliminarlo
          print('🧹 [REGISTER] Intentando limpiar usuario de auth.users...');
          try {
            await _supabase.auth.signOut(scope: SignOutScope.local);
          } catch (cleanupError) {
            print('⚠️ [REGISTER] Error al limpiar usuario: $cleanupError');
          }

          throw UserProfileException('PROFILE_CREATION_FAILED', message);
        }

        print('✅ [REGISTER] Perfil creado exitosamente');
        print('👤 [REGISTER] Usuario registrado: $email (${result['role']})');

        // Retornar UserModel
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
      } on PostgrestException catch (e) {
        print('❌ [REGISTER] Error PostgrestException: ${e.message}');
        print('❌ [REGISTER] Código: ${e.code}');
        print('❌ [REGISTER] Detalles: ${e.details}');

        // Limpiar usuario de Auth
        try {
          await _supabase.auth.signOut(scope: SignOutScope.local);
        } catch (_) {}

        throw UserProfileException(
          'DATABASE_ERROR',
          'Error de base de datos: ${e.message}',
        );
      } catch (e) {
        print('❌ [REGISTER] Error al crear perfil: $e');

        // Limpiar usuario de Auth
        try {
          await _supabase.auth.signOut(scope: SignOutScope.local);
        } catch (_) {}

        throw UserProfileException(
          'PROFILE_CREATION_FAILED',
          'Error al crear el perfil de usuario: ${e.toString()}',
        );
      }
    } on AuthException catch (e) {
      print('❌ [REGISTER] Error AuthException: ${e.message}');

      // Errores comunes de Supabase Auth
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
      print('❌ [REGISTER] Tipo de error: ${e.runtimeType}');

      if (e is AuthServiceException || e is UserProfileException) {
        rethrow;
      }

      throw AuthServiceException(
        'UNKNOWN_ERROR',
        'Error desconocido durante el registro: ${e.toString()}',
      );
    }
  }
}
