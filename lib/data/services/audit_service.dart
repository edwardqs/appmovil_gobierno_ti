import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart'; // <-- 1. IMPORTAR EL MODELO DE USUARIO

class AuditService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Maneja errores de logging de auditoría de manera consistente
  void _handleAuditError(dynamic error, String operation) {
    if (error.toString().contains('row-level security policy')) {
      print(
        '⚠️ [AUDIT] RLS policy blocking audit log insertion for $operation',
      );
      print(
        '   To fix: Execute supabase_audit_logs_fix.sql in Supabase SQL Editor',
      );
    } else {
      print('❌ Error logging $operation: $error');
    }
  }

  /// Registra un intento de login en la base de datos
  Future<void> logLoginAttempt(
      String email, {
        required bool success,
        String? error,
      }) async {
    try {
      final currentUser = _supabase.auth.currentUser;

      await _supabase.from('audit_logs').insert({
        'user_id': currentUser?.id,
        'user_email': email,
        'action': success ? 'login' : 'login_failed',
        'resource_type': 'user',
        'success': success,
        'error_message': error,
        'details': {
          'login_attempt': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });

      print(
        '✅ Login attempt logged for $email: ${success ? 'SUCCESS' : 'FAILURE'}',
      );
    } catch (e) {
      _handleAuditError(e, 'login attempt');
      // No lanzamos excepción para no interrumpir el flujo de login
    }
  }

  /// Registra un logout en la base de datos
  Future<void> logLogout(String? userId, String? email) async {
    try {
      await _supabase.from('audit_logs').insert({
        'user_id': userId,
        'user_email': email,
        'action': 'logout',
        'resource_type': 'user',
        'success': true,
        'details': {'logout_timestamp': DateTime.now().toIso8601String()},
      });

      print('✅ Logout logged for user: $email');
    } catch (e) {
      _handleAuditError(e, 'logout');
    }
  }

  /// Registra activación/desactivación de biometría
  Future<void> logBiometricAction(String userId, bool enabled) async {
    try {
      await _supabase.from('audit_logs').insert({
        'user_id': userId,
        'action': enabled ? 'enable_biometric' : 'disable_biometric',
        'resource_type': 'user',
        'resource_id': userId,
        'success': true,
        'details': {
          'biometric_enabled': enabled,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });

      print('✅ Biometric action logged: ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      _handleAuditError(e, 'biometric action');
    }
  }

  /// Registra la subida de una imagen
  Future<void> logImageUpload(String riskId, String imagePath) async {
    try {
      final currentUser = _supabase.auth.currentUser;

      await _supabase.from('audit_logs').insert({
        'user_id': currentUser?.id,
        'action': 'upload_image',
        'resource_type': 'risk',
        'resource_id': riskId,
        'success': true,
        'details': {
          'image_path': imagePath,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });

      print('✅ Image upload logged for risk: $riskId');
    } catch (e) {
      _handleAuditError(e, 'image upload');
    }
  }

  /// Registra la generación de análisis IA
  Future<void> logAiAnalysis(String riskId) async {
    try {
      final currentUser = _supabase.auth.currentUser;

      await _supabase.from('audit_logs').insert({
        'user_id': currentUser?.id,
        'action': 'generate_ai_analysis',
        'resource_type': 'risk',
        'resource_id': riskId,
        'success': true,
        'details': {
          'analysis_generated': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });

      print('✅ AI analysis logged for risk: $riskId');
    } catch (e) {
      _handleAuditError(e, 'AI analysis');
    }
  }

  /// Obtiene los logs de auditoría (solo para gerentes)
  Future<List<Map<String, dynamic>>> getAuditLogs({
    int limit = 100,
    String? userId,
    String? action,
  }) async {
    try {
      var query = _supabase.from('audit_logs').select('*');

      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      if (action != null) {
        query = query.eq('action', action);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting audit logs: $e');
      throw Exception('Error al obtener los logs de auditoría: $e');
    }
  }

  /// Obtiene estadísticas de actividad del usuario
  Future<Map<String, dynamic>> getUserActivityStats(String userId) async {
    try {
      final response = await _supabase
          .from('audit_logs')
          .select('action, created_at')
          .eq('user_id', userId)
          .gte(
        'created_at',
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      );

      final logs = List<Map<String, dynamic>>.from(response);

      // Contar acciones por tipo
      final actionCounts = <String, int>{};
      for (final log in logs) {
        final action = log['action'] as String;
        actionCounts[action] = (actionCounts[action] ?? 0) + 1;
      }

      return {
        'total_actions': logs.length,
        'action_counts': actionCounts,
        'last_30_days': logs.length,
      };
    } catch (e) {
      print('❌ Error getting user activity stats: $e');
      throw Exception('Error al obtener estadísticas de actividad: $e');
    }
  }

  // ▼▼▼ NUEVA FUNCIÓN AÑADIDA ▼▼▼
  /// Obtiene todos los usuarios con el rol 'auditor_senior' con sus estadísticas
  Future<List<UserModel>> getAvailableAuditors() async {
    try {
      print('🔄 [AuditService] Obteniendo auditores senior con estadísticas...');

      final response = await _supabase
          .from('user_stats') // Usamos la vista user_stats que incluye estadísticas
          .select('id, name, email, role, total_risks_assigned, open_risks, in_progress_risks, pending_review_risks, closed_risks')
          .eq('role', 'auditor_senior'); // Filtramos por el rol

      print('🔍 [AuditService] Respuesta de user_stats: $response');

      // Mapeamos la respuesta a una lista de UserModel con estadísticas
      final auditors = (response as List)
          .map((data) => UserModel.fromMapWithStats(data as Map<String, dynamic>))
          .toList();

      print('✅ [AuditService] ${auditors.length} auditores senior encontrados con estadísticas.');
      return auditors;

    } catch (e) {
      print('❌ [AuditService] Error al obtener auditores disponibles: $e');
      print('❌ [AuditService] Detalles del error: ${e.toString()}');
      throw Exception('Error al obtener auditores disponibles: $e');
    }
  }
// ▲▲▲ FIN DE LA FUNCIÓN AÑADIDA ▲▲▲
}