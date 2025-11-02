// lib/data/services/risk_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/risk_model.dart';
import '../models/user_model.dart';

class RiskService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Genera un nuevo ID único para un riesgo
  String generateNewId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Guarda el análisis de IA para un riesgo específico
  Future<void> saveAiAnalysis(String riskId, String analysisText) async {
    try {
      await _supabase
          .from('risks')
          .update({'ai_analysis': analysisText})
          .eq('id', riskId);
      
      print('✅ Análisis IA guardado para riesgo: $riskId');
    } catch (e) {
      print('❌ Error al guardar análisis IA: $e');
      throw Exception('Error al guardar el análisis IA: $e');
    }
  }

  /// Obtiene todos los riesgos desde Supabase
  Future<List<Risk>> getRisks() async {
    try {
      final response = await _supabase
          .from('risks')
          .select('*')
          .order('created_at', ascending: false);

      return response.map<Risk>((data) => Risk.fromJson(data)).toList();
    } catch (e) {
      print('❌ Error al obtener riesgos: $e');
      throw Exception('Error al cargar los riesgos: $e');
    }
  }

  /// Obtiene riesgos asignados a un usuario específico
  Future<List<Risk>> getRisksByUser(String userId) async {
    try {
      final response = await _supabase
          .from('risks')
          .select('*')
          .eq('assigned_user_id', userId)
          .order('created_at', ascending: false);

      return response.map<Risk>((data) => Risk.fromJson(data)).toList();
    } catch (e) {
      print('❌ Error al obtener riesgos del usuario: $e');
      throw Exception('Error al cargar los riesgos del usuario: $e');
    }
  }

  /// Agrega un nuevo riesgo a Supabase
  Future<Risk> addRisk(Risk newRisk) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      final riskData = {
        'title': newRisk.title,
        'asset': newRisk.asset,
        'status': newRisk.status.name,
        'probability': newRisk.probability,
        'impact': newRisk.impact,
        'control_effectiveness': newRisk.controlEffectiveness,
        'comment': newRisk.comment,
        'assigned_user_id': newRisk.assignedUserId,
        'assigned_user_name': newRisk.assignedUserName,
        'created_by': currentUser.id,
      };

      final response = await _supabase
          .from('risks')
          .insert(riskData)
          .select()
          .single();

      print('✅ Riesgo creado exitosamente: ${response['id']}');
      return Risk.fromJson(response);
    } catch (e) {
      print('❌ Error al crear riesgo: $e');
      throw Exception('Error al crear el riesgo: $e');
    }
  }

  /// Obtiene auditores disponibles usando consulta directa (temporal - sin RLS)
  Future<List<UserModel>> getAuditors() async {
    try {
      print('🔍 [AUDITORS] Obteniendo lista de auditores...');
      
      // Temporal: Devolver lista hardcodeada para evitar problemas de RLS
      // TODO: Corregir políticas RLS en Supabase
      return [
        UserModel(
          id: 'temp-auditor-1',
          name: 'Auditor Junior Temporal',
          email: 'auditor1@temp.com',
          role: UserRole.auditorJunior,
          biometricEnabled: false,
        ),
        UserModel(
          id: 'temp-auditor-2', 
          name: 'Auditor Senior Temporal',
          email: 'auditor2@temp.com',
          role: UserRole.auditorSenior,
          biometricEnabled: false,
        ),
      ];
      
      /* Código original comentado hasta corregir RLS:
      final response = await _supabase
          .from('users')
          .select('id, name, email, role')
          .eq('role', 'auditor');
      
      print('🔍 [AUDITORS] Respuesta: ${response.length} auditores encontrados');
      
      return response.map<UserModel>((data) => UserModel(
        id: data['id'],
        name: data['name'],
        email: data['email'],
        role: UserModel.roleFromString(data['role']),
        biometricEnabled: false,
      )).toList();
      */
    } catch (e) {
      print('❌ Error al obtener auditores: $e');
      throw Exception('Error al cargar los auditores: $e');
    }
  }

  /// Asigna un riesgo a un usuario específico
  Future<void> assignRiskToUser(String riskId, UserModel user) async {
    try {
      await _supabase
          .from('risks')
          .update({
            'assigned_user_id': user.id,
            'assigned_user_name': user.name,
          })
          .eq('id', riskId);

      print('✅ Riesgo $riskId asignado a ${user.name}');
    } catch (e) {
      print('❌ Error al asignar riesgo: $e');
      throw Exception('Error al asignar el riesgo: $e');
    }
  }

  /// Actualiza el estado de un riesgo
  Future<void> updateRiskStatus(
    String riskId,
    RiskStatus newStatus, {
    String? reviewNotes,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus.name,
      };

      if (reviewNotes != null) {
        updateData['review_notes'] = reviewNotes;
      }

      await _supabase
          .from('risks')
          .update(updateData)
          .eq('id', riskId);

      print('✅ Estado del riesgo $riskId actualizado a ${newStatus.name}');
    } catch (e) {
      print('❌ Error al actualizar estado del riesgo: $e');
      throw Exception('Error al actualizar el estado del riesgo: $e');
    }
  }

  /// Actualiza un riesgo completo
  Future<Risk> updateRisk(Risk risk) async {
    try {
      final updateData = {
        'title': risk.title,
        'asset': risk.asset,
        'status': risk.status.name,
        'probability': risk.probability,
        'impact': risk.impact,
        'control_effectiveness': risk.controlEffectiveness,
        'comment': risk.comment,
        'assigned_user_id': risk.assignedUserId,
        'assigned_user_name': risk.assignedUserName,
        'review_notes': risk.reviewNotes,
        'ai_analysis': risk.aiAnalysis,
      };

      final response = await _supabase
          .from('risks')
          .update(updateData)
          .eq('id', risk.id)
          .select()
          .single();

      print('✅ Riesgo ${risk.id} actualizado exitosamente');
      return Risk.fromJson(response);
    } catch (e) {
      print('❌ Error al actualizar riesgo: $e');
      throw Exception('Error al actualizar el riesgo: $e');
    }
  }

  /// Elimina un riesgo (solo para gerentes)
  Future<void> deleteRisk(String riskId) async {
    try {
      await _supabase
          .from('risks')
          .delete()
          .eq('id', riskId);

      print('✅ Riesgo $riskId eliminado exitosamente');
    } catch (e) {
      print('❌ Error al eliminar riesgo: $e');
      throw Exception('Error al eliminar el riesgo: $e');
    }
  }

  /// Obtiene estadísticas del dashboard usando la función de Supabase
  Future<Map<String, dynamic>> getDashboardStats({String? userId}) async {
    try {
      final response = await _supabase.rpc(
        'get_dashboard_stats',
        params: userId != null ? {'user_id_param': userId} : {},
      );

      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('❌ Error al obtener estadísticas: $e');
      throw Exception('Error al cargar las estadísticas: $e');
    }
  }

  /// Agrega un comentario a un riesgo
  Future<void> addRiskComment(String riskId, String comment, {String type = 'general'}) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      await _supabase.from('risk_comments').insert({
        'risk_id': riskId,
        'user_id': currentUser.id,
        'comment': comment,
        'comment_type': type,
      });

      print('✅ Comentario agregado al riesgo $riskId');
    } catch (e) {
      print('❌ Error al agregar comentario: $e');
      throw Exception('Error al agregar el comentario: $e');
    }
  }

  /// Obtiene comentarios de un riesgo
  Future<List<Map<String, dynamic>>> getRiskComments(String riskId) async {
    try {
      final response = await _supabase
          .from('risk_comments')
          .select('''
            *,
            users:user_id (name, email)
          ''')
          .eq('risk_id', riskId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error al obtener comentarios: $e');
      throw Exception('Error al cargar los comentarios: $e');
    }
  }
}
