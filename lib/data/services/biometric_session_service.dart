import 'package:supabase_flutter/supabase_flutter.dart';

class BiometricSessionService {
  final SupabaseClient _supabase;

  BiometricSessionService(this._supabase);

  /// Obtiene todas las sesiones biométricas activas de un usuario
  Future<List<Map<String, dynamic>>> getActiveBiometricSessions(String userId) async {
    try {
      final response = await _supabase
          .from('biometric_sessions')
          .select('''
            id,
            device_id,
            is_active,
            enabled_at,
            last_used_at,
            disabled_at
          ''')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('enabled_at', ascending: false);

      return response;
    } catch (e) {
      print('Error obteniendo sesiones biométricas activas: $e');
      return [];
    }
  }

  /// Obtiene el historial completo de sesiones biométricas
  Future<List<Map<String, dynamic>>> getBiometricSessionHistory(String userId) async {
    try {
      final response = await _supabase
          .from('biometric_sessions')
          .select('''
            id,
            device_id,
            is_active,
            enabled_at,
            last_used_at,
            disabled_at
          ''')
          .eq('user_id', userId)
          .order('enabled_at', ascending: false);

      return response;
    } catch (e) {
      print('Error obteniendo historial de sesiones biométricas: $e');
      return [];
    }
  }

  /// Marca una sesión como usada actualizando last_used_at
  Future<void> markSessionAsUsed(String sessionId) async {
    try {
      await _supabase
          .from('biometric_sessions')
          .update({
            'last_used_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', sessionId);
    } catch (e) {
      print('Error actualizando último uso de sesión: $e');
    }
  }

  /// Desactiva todas las sesiones de un dispositivo específico
  Future<void> deactivateDeviceSessions(String userId, String deviceId) async {
    try {
      await _supabase
          .from('biometric_sessions')
          .update({
            'is_active': false,
            'disabled_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('device_id', deviceId)
          .eq('is_active', true);
    } catch (e) {
      print('Error desactivando sesiones del dispositivo: $e');
    }
  }

  /// Obtiene estadísticas de uso de biometría
  Future<Map<String, dynamic>> getBiometricStats(String userId) async {
    try {
      final activeSessions = await getActiveBiometricSessions(userId);
      final allSessions = await getBiometricSessionHistory(userId);
      
      final totalSessions = allSessions.length;
      final activeCount = activeSessions.length;
      final disabledCount = totalSessions - activeCount;
      
      // Última sesión activa
      final lastActiveSession = activeSessions.isNotEmpty 
          ? activeSessions.first 
          : null;
      
      // Dispositivos únicos
      final uniqueDevices = <String>{};
      for (final session in allSessions) {
        uniqueDevices.add(session['device_id']);
      }

      return {
        'total_sessions': totalSessions,
        'active_sessions': activeCount,
        'disabled_sessions': disabledCount,
        'unique_devices': uniqueDevices.length,
        'last_active_session': lastActiveSession,
        'device_list': uniqueDevices.toList(),
      };
    } catch (e) {
      print('Error obteniendo estadísticas biométricas: $e');
      return {};
    }
  }
}