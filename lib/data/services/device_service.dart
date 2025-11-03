// lib/data/services/device_service.dart

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/device_model.dart';

/// Excepción personalizada para errores de dispositivo
class DeviceServiceException implements Exception {
  final String code;
  final String message;

  DeviceServiceException(this.code, this.message);

  @override
  String toString() => 'DeviceServiceException: [$code] $message';
}

/// Servicio para gestionar dispositivos registrados de usuarios
class DeviceService {
  final SupabaseClient _supabase;

  DeviceService(this._supabase);

  // ==========================================================================
  // OBTENCIÓN DE INFORMACIÓN DEL DISPOSITIVO
  // ==========================================================================

  /// Obtiene el ID único del dispositivo actual
  Future<String> getDeviceId() async {
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

      print('📱 [DEVICE_SERVICE] Device ID obtenido: $deviceId');
      return deviceId;
    } catch (e) {
      print('❌ [DEVICE_SERVICE] Error al obtener Device ID: $e');
      throw DeviceServiceException(
        'DEVICE_ID_ERROR',
        'No se pudo obtener el ID del dispositivo',
      );
    }
  }

  /// Obtiene información completa del dispositivo actual
  Future<Map<String, String?>> getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      Map<String, String?> info = {};

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        info = {
          'device_id': androidInfo.id,
          'device_name': androidInfo.model,
          'device_model':
              '${androidInfo.brand} ${androidInfo.model}',
          'os_version': 'Android ${androidInfo.version.release}',
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        info = {
          'device_id': iosInfo.identifierForVendor ?? 'unknown_ios',
          'device_name': iosInfo.name,
          'device_model': iosInfo.model,
          'os_version': 'iOS ${iosInfo.systemVersion}',
        };
      } else {
        info = {
          'device_id': 'unknown_platform',
          'device_name': 'Dispositivo desconocido',
          'device_model': 'Plataforma no soportada',
          'os_version': 'N/A',
        };
      }

      print('📱 [DEVICE_SERVICE] Info del dispositivo: $info');
      return info;
    } catch (e) {
      print('❌ [DEVICE_SERVICE] Error al obtener info del dispositivo: $e');
      throw DeviceServiceException(
        'DEVICE_INFO_ERROR',
        'No se pudo obtener información del dispositivo',
      );
    }
  }

  // ==========================================================================
  // REGISTRO Y GESTIÓN DE DISPOSITIVOS
  // ==========================================================================

  /// Registra o actualiza el dispositivo actual para el usuario
  Future<DeviceModel> registerCurrentDevice(String userId) async {
    try {
      print('📱 [DEVICE_SERVICE] Registrando dispositivo actual...');

      final deviceInfo = await getDeviceInfo();

      final response = await _supabase.rpc(
        'register_user_device',
        params: {
          'p_user_id': userId,
          'p_device_id': deviceInfo['device_id'],
          'p_device_name': deviceInfo['device_name'],
          'p_device_model': deviceInfo['device_model'],
          'p_os_version': deviceInfo['os_version'],
        },
      );

      if (response == null) {
        throw DeviceServiceException(
          'REGISTRATION_FAILED',
          'No se recibió respuesta al registrar el dispositivo',
        );
      }

      final result = response;
      final success = result['success'] as bool? ?? false;
      final message = result['message'] as String? ?? 'Error desconocido';

      if (!success) {
        print('❌ [DEVICE_SERVICE] Error al registrar: $message');
        throw DeviceServiceException('REGISTRATION_FAILED', message);
      }

      final deviceData = result['device'] as Map<String, dynamic>;
      final device = DeviceModel.fromJson(deviceData);

      print('✅ [DEVICE_SERVICE] Dispositivo registrado: ${device.displayName}');
      return device;
    } catch (e) {
      print('❌ [DEVICE_SERVICE] Error al registrar dispositivo: $e');
      if (e is DeviceServiceException) rethrow;
      throw DeviceServiceException(
        'REGISTRATION_ERROR',
        'Error al registrar dispositivo: ${e.toString()}',
      );
    }
  }

  /// Actualiza la marca de tiempo last_used_at del dispositivo actual
  Future<void> updateDeviceLastUsed(String userId, String deviceId) async {
    try {
      print('🔄 [DEVICE_SERVICE] Actualizando last_used_at...');

      final result = await _supabase.rpc(
        'update_device_last_used',
        params: {
          'p_user_id': userId,
          'p_device_id': deviceId,
        },
      );

      if (result == true) {
        print('✅ [DEVICE_SERVICE] last_used_at actualizado');
      } else {
        print('⚠️ [DEVICE_SERVICE] No se pudo actualizar last_used_at');
      }
    } catch (e) {
      print('❌ [DEVICE_SERVICE] Error al actualizar last_used_at: $e');
      // No lanzamos excepción porque no es crítico
    }
  }

  /// Desactiva un dispositivo específico
  Future<bool> deactivateDevice(String userId, String deviceId) async {
    try {
      print('🔐 [DEVICE_SERVICE] Desactivando dispositivo: $deviceId');

      final response = await _supabase.rpc(
        'deactivate_device',
        params: {
          'p_user_id': userId,
          'p_device_id': deviceId,
        },
      );

      if (response == null) {
        throw DeviceServiceException(
          'DEACTIVATION_FAILED',
          'No se recibió respuesta al desactivar el dispositivo',
        );
      }

      final result = response as Map<String, dynamic>;
      final success = result['success'] as bool? ?? false;

      if (success) {
        print('✅ [DEVICE_SERVICE] Dispositivo desactivado exitosamente');
      } else {
        print('❌ [DEVICE_SERVICE] Error: ${result['message']}');
      }

      return success;
    } catch (e) {
      print('❌ [DEVICE_SERVICE] Error al desactivar dispositivo: $e');
      if (e is DeviceServiceException) rethrow;
      throw DeviceServiceException(
        'DEACTIVATION_ERROR',
        'Error al desactivar dispositivo: ${e.toString()}',
      );
    }
  }

  // ==========================================================================
  // CONSULTAS DE DISPOSITIVOS
  // ==========================================================================

  /// Obtiene todos los dispositivos de un usuario
  Future<List<DeviceModel>> getUserDevices(String userId) async {
    try {
      print('📱 [DEVICE_SERVICE] Obteniendo dispositivos del usuario...');

      final response = await _supabase
          .from('user_devices')
          .select()
          .eq('user_id', userId)
          .order('last_used_at', ascending: false);

      final devices = (response as List)
          .map((data) => DeviceModel.fromJson(data as Map<String, dynamic>))
          .toList();

      print('✅ [DEVICE_SERVICE] ${devices.length} dispositivos encontrados');
      return devices;
    } catch (e) {
      print('❌ [DEVICE_SERVICE] Error al obtener dispositivos: $e');
      throw DeviceServiceException(
        'FETCH_ERROR',
        'Error al obtener dispositivos: ${e.toString()}',
      );
    }
  }

  /// Obtiene solo los dispositivos activos de un usuario
  Future<List<DeviceModel>> getActiveDevices(String userId) async {
    try {
      print('📱 [DEVICE_SERVICE] Obteniendo dispositivos activos...');

      final response = await _supabase
          .from('user_devices')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('last_used_at', ascending: false);

      final devices = (response as List)
          .map((data) => DeviceModel.fromJson(data as Map<String, dynamic>))
          .toList();

      print(
        '✅ [DEVICE_SERVICE] ${devices.length} dispositivos activos encontrados',
      );
      return devices;
    } catch (e) {
      print('❌ [DEVICE_SERVICE] Error al obtener dispositivos activos: $e');
      throw DeviceServiceException(
        'FETCH_ERROR',
        'Error al obtener dispositivos activos: ${e.toString()}',
      );
    }
  }

  /// Verifica si un dispositivo específico está registrado y activo
  Future<bool> isDeviceRegistered(String userId, String deviceId) async {
    try {
      print('🔍 [DEVICE_SERVICE] Verificando si dispositivo está registrado...');

      final result = await _supabase.rpc(
        'is_device_registered',
        params: {
          'p_user_id': userId,
          'p_device_id': deviceId,
        },
      );

      final isRegistered = result as bool? ?? false;

      print(
        '${isRegistered ? '✅' : '❌'} [DEVICE_SERVICE] Dispositivo ${isRegistered ? 'registrado' : 'no registrado'}',
      );
      return isRegistered;
    } catch (e) {
      print('❌ [DEVICE_SERVICE] Error al verificar registro: $e');
      return false;
    }
  }

  /// Obtiene un dispositivo específico
  Future<DeviceModel?> getDevice(String userId, String deviceId) async {
    try {
      print('📱 [DEVICE_SERVICE] Obteniendo dispositivo específico...');

      final response = await _supabase
          .from('user_devices')
          .select()
          .eq('user_id', userId)
          .eq('device_id', deviceId)
          .maybeSingle();

      if (response == null) {
        print('ℹ️ [DEVICE_SERVICE] Dispositivo no encontrado');
        return null;
      }

      final device = DeviceModel.fromJson(response as Map<String, dynamic>);
      print('✅ [DEVICE_SERVICE] Dispositivo encontrado: ${device.displayName}');
      return device;
    } catch (e) {
      print('❌ [DEVICE_SERVICE] Error al obtener dispositivo: $e');
      throw DeviceServiceException(
        'FETCH_ERROR',
        'Error al obtener dispositivo: ${e.toString()}',
      );
    }
  }

  // ==========================================================================
  // ESTADÍSTICAS Y UTILIDADES
  // ==========================================================================

  /// Obtiene el conteo de dispositivos activos de un usuario
  Future<int> getActiveDeviceCount(String userId) async {
    try {
      final devices = await getActiveDevices(userId);
      return devices.length;
    } catch (e) {
      print('❌ [DEVICE_SERVICE] Error al contar dispositivos: $e');
      return 0;
    }
  }

  /// Limpia dispositivos inactivos antiguos (más de 90 días sin uso)
  Future<int> cleanupOldDevices(String userId) async {
    try {
      print('🧹 [DEVICE_SERVICE] Limpiando dispositivos antiguos...');

      final cutoffDate =
          DateTime.now().subtract(const Duration(days: 90)).toIso8601String();

      final response = await _supabase
          .from('user_devices')
          .delete()
          .eq('user_id', userId)
          .eq('is_active', false)
          .lt('last_used_at', cutoffDate)
          .select();

      final deletedCount = (response as List?)?.length ?? 0;

      print('✅ [DEVICE_SERVICE] $deletedCount dispositivos eliminados');
      return deletedCount;
    } catch (e) {
      print('❌ [DEVICE_SERVICE] Error al limpiar dispositivos: $e');
      return 0;
    }
  }
}
