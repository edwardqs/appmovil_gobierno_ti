// lib/data/services/auth_service.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'biometric_service.dart';

class AuthService {
  final BiometricService _biometricService = BiometricService();
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<UserModel?> login(String email, String password) async {
    try {
      print('Attempting login with email: $email');
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      print('Auth response: ${response.user?.id}');
      if (response.user != null) {
        // Obtener perfil completo del usuario
        final profileResponse = await _supabase.rpc(
          'get_user_profile',
          params: {'p_user_id': response.user!.id},
        );
        
        if (profileResponse != null && profileResponse['success'] == true) {
          final userData = profileResponse['user'];
          return UserModel(
            id: userData['id'],
            name: userData['name'],
            email: userData['email'],
            role: UserModel.roleFromString(userData['role']),
            biometricEnabled: userData['biometric_enabled'] ?? false,
            dni: userData['dni'],
            phone: userData['phone'],
            address: userData['address'],
          );
        } else {
          print('Error getting user profile: ${profileResponse?['message']}');
        }
      }

      return null;
    } catch (e) {
      print('Error during login: $e');
      return null;
    }
  }

  Future<void> logout() async {
    try {
      // Cerrar sesión en Supabase
      await _supabase.auth.signOut();
      // Limpiar datos biométricos almacenados
      await _clearBiometricData();
    } catch (e) {
      print('Error during logout: $e');
      // Aún así limpiar datos locales
      await _clearBiometricData();
    }
  }

  // Registrar nuevo usuario con Supabase
  Future<Map<String, dynamic>> registerUser({
    required String name,
    required String email,
    required String password,
    required String dni,
    required String phone,
    required String address,
    bool enableBiometric = false,
    String? deviceId,
    String? biometricHash,
  }) async {
    try {
      print('📝 AuthService: Llamando register_user con parámetros:');
      print('📝 AuthService: enableBiometric: $enableBiometric');
      print('📝 AuthService: deviceId: $deviceId');
      print('📝 AuthService: biometricHash: ${biometricHash?.substring(0, 10)}...');
      
      final response = await _supabase.rpc('register_user', params: {
        'p_name': name,
        'p_email': email,
        'p_password': password,
        'p_dni': dni,
        'p_phone': phone,
        'p_address': address,
        'p_device_id': deviceId,
        'p_biometric_hash': biometricHash,
      });

      print('📝 AuthService: Respuesta completa de Supabase: $response');

      if (response != null && response['success'] == true) {
        print('📝 AuthService: Registro exitoso, procesando datos biométricos...');
        print('📝 AuthService: response biometric_token: ${response['biometric_token']}');
        
        final user = UserModel(
          id: response['user_id'],
          name: response['name'],
          email: response['email'],
          role: null, // Sin rol asignado inicialmente
          biometricEnabled: enableBiometric,
          dni: response['dni'],
          phone: response['phone'],
          address: response['address'],
        );

        Map<String, dynamic> result = {
          'success': true,
          'user': user,
          'message': response['message'],
        };

        // Si se habilitó biometría, configurar token
        if (enableBiometric && response['biometric_token'] != null) {
          print('📝 AuthService: Guardando datos biométricos localmente...');
          result['biometric_data'] = {
            'token': response['biometric_token']['token'],
            'device_id': deviceId,
            'expires_at': response['biometric_token']['expires_at'],
          };
          
          // Guardar datos biométricos localmente
          if (deviceId != null) {
            print('📝 AuthService: Llamando _saveBiometricData con userId: ${user.id}, deviceId: $deviceId');
            await _saveBiometricData(
              user.id,
              response['biometric_token']['token'],
              deviceId,
              biometricHash!,
            );
            print('📝 AuthService: Datos biométricos guardados exitosamente');
            
            // Verificar que se guardaron correctamente
            final savedData = await hasBiometricData();
            print('📝 AuthService: Verificación post-guardado - hasBiometricData: $savedData');
          } else {
            print('📝 AuthService: ERROR - deviceId es null, no se pueden guardar datos biométricos');
          }
        } else {
          print('📝 AuthService: No se guardaron datos biométricos - enableBiometric: $enableBiometric, biometric_token: ${response['biometric_token']}');
        }

        return result;
      }

      return {
        'success': false,
        'message': response?['message'] ?? 'Error al registrar usuario',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error inesperado: $e',
      };
    }
  }

  // Login con biometría
  Future<UserModel?> loginWithBiometrics() async {
    try {
      final biometricData = await _getBiometricData();
      
      if (biometricData == null) {
        return null;
      }

      return await _biometricService.loginWithBiometrics(
        biometricData['token']!,
        biometricData['device_id']!,
        biometricData['biometric_hash']!,
      );
    } catch (e) {
      print('Error during biometric login: $e');
      return null;
    }
  }

  // Configurar biometría para usuario existente
  Future<Map<String, dynamic>?> setupBiometricAuthentication(UserModel user) async {
    final result = await _biometricService.setupBiometricForUser(user);
    
    if (result != null && result['success'] == true) {
      // Guardar datos biométricos localmente
      await _saveBiometricData(
        user.id,
        result['token'],
        result['device_id'],
        result['biometric_hash'],
      );
    }
    
    return result;
  }

  // Habilitar biometría para usuario autenticado (desde la app)
  Future<Map<String, dynamic>> enableBiometricForCurrentUser() async {
    print('🔧 enableBiometricForCurrentUser: Iniciando proceso...');
    try {
      // Verificar si la biometría está disponible en el dispositivo
      print('🔧 enableBiometricForCurrentUser: Verificando disponibilidad de biometría...');
      final isAvailable = await _biometricService.hasBiometrics();
      print('🔧 enableBiometricForCurrentUser: Biometría disponible: $isAvailable');
      
      if (!isAvailable) {
        print('🔧 enableBiometricForCurrentUser: Biometría no disponible, retornando error');
        return {
          'success': false,
          'message': 'Biometría no disponible en este dispositivo',
        };
      }

      print('🔧 enableBiometricForCurrentUser: Verificando usuario actual de Supabase...');
      final currentSupabaseUser = _supabase.auth.currentUser;
      print('🔧 enableBiometricForCurrentUser: Usuario actual: ${currentSupabaseUser?.id}');
      
      if (currentSupabaseUser == null) {
        print('🔧 enableBiometricForCurrentUser: No hay usuario autenticado en Supabase');
        return {
          'success': false,
          'message': 'No hay usuario autenticado',
        };
      }

      // *** PASO CRÍTICO: Solicitar autenticación biométrica para registrar ***
      print('🔧 enableBiometricForCurrentUser: Solicitando autenticación biométrica para registro...');
      final isAuthenticated = await _biometricService.authenticate(
        'Registra tu huella dactilar o rostro para habilitar el acceso rápido'
      );
      
      if (!isAuthenticated) {
        print('🔧 enableBiometricForCurrentUser: Autenticación biométrica cancelada por el usuario');
        return {
          'success': false,
          'message': 'Registro biométrico cancelado. Necesitas registrar tu huella o rostro para continuar.',
        };
      }
      
      print('🔧 enableBiometricForCurrentUser: Autenticación biométrica exitosa, continuando...');
      print('🔧 enableBiometricForCurrentUser: Obteniendo deviceId...');
      final deviceId = await _biometricService.getDeviceId();
      print('🔧 enableBiometricForCurrentUser: deviceId: $deviceId');
      
      print('🔧 enableBiometricForCurrentUser: Generando hash biométrico...');
      final biometricHash = _generateBiometricHash(currentSupabaseUser.id, deviceId);
      print('🔧 enableBiometricForCurrentUser: Hash generado: $biometricHash');

      // Llamar a la función de Supabase para habilitar biometría
      print('🔧 enableBiometricForCurrentUser: Llamando a setup_biometric_for_user...');
      final response = await _supabase.rpc('setup_biometric_for_user', params: {
        'p_device_id': deviceId,
        'p_biometric_hash': biometricHash,
      });
      print('🔧 enableBiometricForCurrentUser: Respuesta de Supabase: $response');

      if (response != null && response['success'] == true) {
        print('🔧 enableBiometricForCurrentUser: Respuesta exitosa, guardando datos localmente...');
        // Guardar datos biométricos localmente
        await _saveBiometricData(
          currentSupabaseUser.id,
          response['token'],
          deviceId,
          biometricHash,
        );
        print('🔧 enableBiometricForCurrentUser: Datos guardados exitosamente');

        return {
          'success': true,
          'message': 'Biometría registrada y habilitada exitosamente. Ahora puedes usar tu huella o rostro para acceder.',
          'token': response['token'],
          'expires_at': response['expires_at'],
        };
      }

      print('🔧 enableBiometricForCurrentUser: Respuesta no exitosa de Supabase');
      return {
        'success': false,
        'message': response?['message'] ?? 'Error al habilitar biometría',
      };
    } catch (e) {
      print('🔧 enableBiometricForCurrentUser: Error capturado: $e');
      print('🔧 enableBiometricForCurrentUser: Tipo de error: ${e.runtimeType}');
      return {
        'success': false,
        'message': 'Error inesperado: $e',
      };
    }
  }

  // Deshabilitar biometría para usuario autenticado
  Future<Map<String, dynamic>> disableBiometricForCurrentUser() async {
    try {
      // Llamar a la función de Supabase para deshabilitar biometría
      final response = await _supabase.rpc('disable_biometric_for_user');

      if (response != null && response['success'] == true) {
        // Limpiar datos biométricos locales
        await _clearBiometricData();

        return {
          'success': true,
          'message': response['message'],
        };
      }

      return {
        'success': false,
        'message': response?['message'] ?? 'Error al deshabilitar biometría',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error inesperado: $e',
      };
    }
  }



  // Verificar si hay datos biométricos guardados
  Future<bool> hasBiometricData() async {
    print('🔐 AuthService: Verificando datos biométricos...');
    final prefs = await SharedPreferences.getInstance();
    
    final hasToken = prefs.containsKey('biometric_token');
    final hasDeviceId = prefs.containsKey('biometric_device_id');
    final hasUserId = prefs.containsKey('biometric_user_id');
    final hasHash = prefs.containsKey('biometric_hash');
    
    print('🔐 AuthService: biometric_token: $hasToken');
    print('🔐 AuthService: biometric_device_id: $hasDeviceId');
    print('🔐 AuthService: biometric_user_id: $hasUserId');
    print('🔐 AuthService: biometric_hash: $hasHash');
    
    final result = hasToken && hasDeviceId && hasUserId && hasHash;
    print('🔐 AuthService: hasBiometricData resultado: $result');
    
    return result;
  }

  // Verificar disponibilidad de biometría
  Future<bool> isBiometricAvailable() async {
    return await _biometricService.hasBiometrics();
  }

  // Métodos privados para manejo de datos biométricos
  Future<void> _saveBiometricData(String userId, String token, String deviceId, String biometricHash) async {
    print('💾 _saveBiometricData: Iniciando guardado...');
    print('💾 _saveBiometricData: userId: $userId');
    print('💾 _saveBiometricData: token: $token');
    print('💾 _saveBiometricData: deviceId: $deviceId');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('biometric_user_id', userId);
    await prefs.setString('biometric_token', token);
    await prefs.setString('biometric_device_id', deviceId);
    
    await prefs.setString('biometric_hash', biometricHash);
    
    print('💾 _saveBiometricData: biometricHash generado: $biometricHash');
    print('💾 _saveBiometricData: Datos guardados en SharedPreferences');
    
    // Verificar que se guardaron
    final savedUserId = prefs.getString('biometric_user_id');
    final savedToken = prefs.getString('biometric_token');
    final savedDeviceId = prefs.getString('biometric_device_id');
    final savedHash = prefs.getString('biometric_hash');
    
    print('💾 _saveBiometricData: Verificación - userId guardado: $savedUserId');
    print('💾 _saveBiometricData: Verificación - token guardado: $savedToken');
    print('💾 _saveBiometricData: Verificación - deviceId guardado: $savedDeviceId');
    print('💾 _saveBiometricData: Verificación - hash guardado: $savedHash');
  }

  Future<Map<String, String>?> _getBiometricData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final userId = prefs.getString('biometric_user_id');
    final token = prefs.getString('biometric_token');
    final deviceId = prefs.getString('biometric_device_id');
    final biometricHash = prefs.getString('biometric_hash');
    
    if (userId != null && token != null && deviceId != null && biometricHash != null) {
      return {
        'user_id': userId,
        'token': token,
        'device_id': deviceId,
        'biometric_hash': biometricHash,
      };
    }
    
    return null;
  }

  Future<void> _clearBiometricData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('biometric_user_id');
    await prefs.remove('biometric_token');
    await prefs.remove('biometric_device_id');
    await prefs.remove('biometric_hash');
  }

  String _generateBiometricHash(String userId, String deviceId) {
    final String data = '$userId-$deviceId-${DateTime.now().millisecondsSinceEpoch}';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}