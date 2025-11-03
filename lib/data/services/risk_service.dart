import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/risk_model.dart';
import '../models/user_model.dart';
import 'package:uuid/uuid.dart';

// ============================================================================
// EXCEPCIONES PERSONALIZADAS
// ============================================================================

class RiskServiceException implements Exception {
  final String code;
  final String message;

  RiskServiceException(this.code, this.message);

  @override
  String toString() => 'RiskServiceException: [$code] $message';
}

// ============================================================================
// RISK SERVICE
// ============================================================================

class RiskService {
  // ✅ CORREGIDO: Ahora usa una instancia pasada por parámetro o la por defecto
  final SupabaseClient _supabase;

  // Constructor que acepta un SupabaseClient opcional
  RiskService([SupabaseClient? supabaseClient])
    : _supabase = supabaseClient ?? Supabase.instance.client;

  // ==========================================================================
  // GENERACIÓN DE IDs
  // ==========================================================================

  /// Genera un nuevo ID único para un riesgo (UUID)
  String generateNewId() {
    const uuid = Uuid();
    return uuid.v4();
  }

  // ==========================================================================
  // GESTIÓN DE IMÁGENES
  // ==========================================================================

  /// Sube una imagen a Supabase Storage y retorna la URL pública
  Future<String?> uploadImage(String imagePath, String riskId) async {
    try {
      print('📸 [UPLOAD_IMAGE] Iniciando subida de imagen: $imagePath');

      final file = File(imagePath);
      if (!await file.exists()) {
        print('❌ [UPLOAD_IMAGE] Archivo no encontrado: $imagePath');
        throw RiskServiceException(
          'FILE_NOT_FOUND',
          'El archivo de imagen no existe',
        );
      }

      final fileSize = await file.length();
      print('✅ [UPLOAD_IMAGE] Archivo existe, tamaño: $fileSize bytes');

      // Validar tamaño máximo (10MB)
      if (fileSize > 10 * 1024 * 1024) {
        throw RiskServiceException(
          'FILE_TOO_LARGE',
          'La imagen es demasiado grande (máx. 10MB)',
        );
      }

      // Generar nombre único para la imagen
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imagePath.split('.').last.toLowerCase();
      final fileName = '${riskId}_$timestamp.$extension';
      final filePath = 'risk-images/$fileName';

      print('🔄 [UPLOAD_IMAGE] Nombre de archivo generado: $fileName');
      print('🔄 [UPLOAD_IMAGE] Ruta en storage: $filePath');

      String? publicUrl;

      // Intentar subir a diferentes buckets
      final bucketsToTry = ['images', 'risk-attachments', 'risk-images'];

      for (final bucket in bucketsToTry) {
        try {
          print('🔄 [UPLOAD_IMAGE] Intentando subir a bucket "$bucket"...');

          await _supabase.storage
              .from(bucket)
              .upload(
                filePath,
                file,
                fileOptions: const FileOptions(
                  cacheControl: '3600',
                  upsert: false,
                ),
              );

          publicUrl = _supabase.storage.from(bucket).getPublicUrl(filePath);

          print('✅ [UPLOAD_IMAGE] Subida exitosa a bucket "$bucket"');
          break;
        } catch (e) {
          print('⚠️ [UPLOAD_IMAGE] Bucket "$bucket" no disponible: $e');

          if (bucket == bucketsToTry.last) {
            throw RiskServiceException(
              'STORAGE_ERROR',
              'No se pudo subir la imagen. Verifica la configuración de Storage en Supabase.',
            );
          }
        }
      }

      if (publicUrl == null) {
        throw RiskServiceException(
          'UPLOAD_FAILED',
          'No se pudo obtener la URL pública de la imagen',
        );
      }

      print('🔄 [UPLOAD_IMAGE] URL pública generada: $publicUrl');

      // ✅ Auditoría removida temporalmente
      // TODO: Implementar sistema de auditoría si es necesario

      print('✅ [UPLOAD_IMAGE] Imagen subida exitosamente');
      return publicUrl;
    } on RiskServiceException {
      rethrow;
    } catch (e) {
      print('❌ [UPLOAD_IMAGE] Error general: $e');
      throw RiskServiceException(
        'UPLOAD_ERROR',
        'Error al subir imagen: ${e.toString()}',
      );
    }
  }

  /// Sube múltiples imágenes y retorna las URLs
  Future<List<String>> uploadImages(
    List<String> imagePaths,
    String riskId,
  ) async {
    print('📸 [UPLOAD_IMAGES] Subiendo ${imagePaths.length} imágenes...');

    final List<String> uploadedUrls = [];
    final List<String> failedUploads = [];

    for (int i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      print(
        '📸 [UPLOAD_IMAGES] Procesando imagen ${i + 1}/${imagePaths.length}',
      );

      try {
        final url = await uploadImage(imagePath, riskId);
        if (url != null) {
          uploadedUrls.add(url);
        } else {
          failedUploads.add(imagePath);
        }
      } catch (e) {
        print('❌ [UPLOAD_IMAGES] Error al subir imagen $imagePath: $e');
        failedUploads.add(imagePath);
      }
    }

    print(
      '✅ [UPLOAD_IMAGES] ${uploadedUrls.length}/${imagePaths.length} imágenes subidas exitosamente',
    );

    if (failedUploads.isNotEmpty) {
      print('⚠️ [UPLOAD_IMAGES] ${failedUploads.length} imágenes fallaron');
    }

    return uploadedUrls;
  }

  // ==========================================================================
  // GESTIÓN DE ANÁLISIS IA
  // ==========================================================================

  /// Guarda el análisis de IA para un riesgo específico
  Future<void> saveAiAnalysis(String riskId, String analysisText) async {
    try {
      print('💾 [AI_ANALYSIS] Guardando análisis para riesgo: $riskId');

      await _supabase
          .from('risks')
          .update({'ai_analysis': analysisText})
          .eq('id', riskId);

      print('✅ [AI_ANALYSIS] Análisis guardado exitosamente');

      // ✅ Auditoría removida temporalmente
      // TODO: Implementar sistema de auditoría si es necesario
    } catch (e) {
      print('❌ [AI_ANALYSIS] Error al guardar análisis: $e');
      throw RiskServiceException(
        'SAVE_ANALYSIS_ERROR',
        'Error al guardar el análisis IA: ${e.toString()}',
      );
    }
  }

  // ==========================================================================
  // CONSULTAS DE RIESGOS
  // ==========================================================================

  /// Obtiene todos los riesgos desde Supabase
  Future<List<Risk>> getRisks() async {
    try {
      print('🔍 [GET_RISKS] Obteniendo todos los riesgos...');

      final response = await _supabase
          .from('risks')
          .select('*')
          .order('created_at', ascending: false);

      final risks = (response as List)
          .map<Risk>((data) => Risk.fromJson(data))
          .toList();

      print('✅ [GET_RISKS] ${risks.length} riesgos obtenidos');
      return risks;
    } catch (e) {
      print('❌ [GET_RISKS] Error al obtener riesgos: $e');
      throw RiskServiceException(
        'FETCH_RISKS_ERROR',
        'Error al cargar los riesgos: ${e.toString()}',
      );
    }
  }

  /// Obtiene riesgos asignados a un usuario específico
  Future<List<Risk>> getRisksByUser(String userId) async {
    try {
      print('🔍 [GET_RISKS_BY_USER] Obteniendo riesgos para usuario: $userId');

      final response = await _supabase
          .from('risks')
          .select('*')
          .eq('assigned_user_id', userId)
          .order('created_at', ascending: false);

      final risks = (response as List)
          .map<Risk>((data) => Risk.fromJson(data))
          .toList();

      print('✅ [GET_RISKS_BY_USER] ${risks.length} riesgos encontrados');
      return risks;
    } catch (e) {
      print('❌ [GET_RISKS_BY_USER] Error: $e');
      throw RiskServiceException(
        'FETCH_USER_RISKS_ERROR',
        'Error al cargar los riesgos del usuario: ${e.toString()}',
      );
    }
  }

  /// Obtiene un riesgo específico por su ID
  Future<Risk?> getRiskById(String riskId) async {
    try {
      print('🔍 [GET_RISK_BY_ID] Obteniendo riesgo: $riskId');

      final response = await _supabase
          .from('risks')
          .select('*')
          .eq('id', riskId)
          .maybeSingle();

      if (response == null) {
        print('⚠️ [GET_RISK_BY_ID] Riesgo no encontrado: $riskId');
        return null;
      }

      final risk = Risk.fromJson(response);
      print('✅ [GET_RISK_BY_ID] Riesgo obtenido: ${risk.title}');
      print(
        '🔍 [GET_RISK_BY_ID] AI Analysis presente: ${risk.aiAnalysis != null ? "Sí (${risk.aiAnalysis!.length} chars)" : "No"}',
      );

      return risk;
    } catch (e) {
      print('❌ [GET_RISK_BY_ID] Error: $e');
      throw RiskServiceException(
        'FETCH_RISK_BY_ID_ERROR',
        'Error al obtener el riesgo: ${e.toString()}',
      );
    }
  }

  // ==========================================================================
  // CREACIÓN Y ACTUALIZACIÓN DE RIESGOS
  // ==========================================================================

  /// Agrega un nuevo riesgo a Supabase
  Future<Risk> addRisk(Risk newRisk) async {
    try {
      print('🔄 [ADD_RISK] Iniciando creación de riesgo...');
      print('🔄 [ADD_RISK] Título: ${newRisk.title}');
      print('🔄 [ADD_RISK] Asset: ${newRisk.asset}');
      print('🔄 [ADD_RISK] Imágenes a subir: ${newRisk.imagePaths.length}');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        print('❌ [ADD_RISK] Usuario no autenticado');
        throw RiskServiceException(
          'NOT_AUTHENTICATED',
          'Debes estar autenticado para crear riesgos',
        );
      }

      print('✅ [ADD_RISK] Usuario autenticado: ${currentUser.email}');

      // Generar ID único para el riesgo
      final riskId = generateNewId();
      print('🔄 [ADD_RISK] ID generado: $riskId');

      // Subir imágenes si existen
      List<String> imageUrls = [];
      if (newRisk.imagePaths.isNotEmpty) {
        print(
          '📸 [ADD_RISK] Subiendo ${newRisk.imagePaths.length} imágenes...',
        );
        try {
          imageUrls = await uploadImages(newRisk.imagePaths, riskId);
          print('✅ [ADD_RISK] ${imageUrls.length} imágenes subidas');
        } catch (e) {
          print('⚠️ [ADD_RISK] Error al subir imágenes: $e');
          // Continuar sin imágenes si falla la subida
        }
      } else {
        print('ℹ️ [ADD_RISK] No hay imágenes para subir');
      }

      final riskData = {
        'id': riskId,
        'title': newRisk.title,
        'asset': newRisk.asset,
        'status': Risk.statusToString(
          newRisk.status,
        ), // ← CAMBIO: usar snake_case
        'probability': newRisk.probability,
        'impact': newRisk.impact,
        'control_effectiveness': newRisk.controlEffectiveness,
        'comment': newRisk.comment,
        'image_paths': imageUrls,
        'assigned_user_id': newRisk.assignedUserId,
        'assigned_user_name': newRisk.assignedUserName,
        'created_by': currentUser.id,
        'created_at': DateTime.now().toIso8601String(),
      };

      print('🔄 [ADD_RISK] Insertando en Supabase...');

      final response = await _supabase
          .from('risks')
          .insert(riskData)
          .select()
          .single();

      print('✅ [ADD_RISK] Riesgo creado: ${response['id']}');

      final createdRisk = Risk.fromJson(response);
      return createdRisk;
    } on RiskServiceException {
      rethrow;
    } catch (e) {
      print('❌ [ADD_RISK] Error: $e');
      throw RiskServiceException(
        'CREATE_RISK_ERROR',
        'Error al crear el riesgo: ${e.toString()}',
      );
    }
  }

  /// Actualiza el estado de un riesgo
  Future<void> updateRiskStatus(
    String riskId,
    RiskStatus newStatus, {
    String? reviewNotes,
  }) async {
    try {
      print(
        '🔄 [UPDATE_STATUS] Actualizando riesgo $riskId a ${newStatus.name}',
      );

      final updateData = <String, dynamic>{
        'status': Risk.statusToString(newStatus), // ← CAMBIO: usar snake_case
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (reviewNotes != null) {
        updateData['review_notes'] = reviewNotes;
      }

      await _supabase.from('risks').update(updateData).eq('id', riskId);

      print('✅ [UPDATE_STATUS] Estado actualizado exitosamente');
    } catch (e) {
      print('❌ [UPDATE_STATUS] Error: $e');
      throw RiskServiceException(
        'UPDATE_STATUS_ERROR',
        'Error al actualizar el estado: ${e.toString()}',
      );
    }
  }

  /// Actualiza un riesgo completo
  Future<Risk> updateRisk(Risk risk) async {
    try {
      print('🔄 [UPDATE_RISK] Actualizando riesgo: ${risk.id}');

      final updateData = {
        'title': risk.title,
        'asset': risk.asset,
        'status': Risk.statusToString(risk.status), // ← CAMBIO: usar snake_case
        'probability': risk.probability,
        'impact': risk.impact,
        'control_effectiveness': risk.controlEffectiveness,
        'comment': risk.comment,
        'assigned_user_id': risk.assignedUserId,
        'assigned_user_name': risk.assignedUserName,
        'review_notes': risk.reviewNotes,
        'ai_analysis': risk.aiAnalysis,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('risks')
          .update(updateData)
          .eq('id', risk.id)
          .select()
          .single();

      print('✅ [UPDATE_RISK] Riesgo actualizado exitosamente');
      return Risk.fromJson(response);
    } catch (e) {
      print('❌ [UPDATE_RISK] Error: $e');
      throw RiskServiceException(
        'UPDATE_RISK_ERROR',
        'Error al actualizar el riesgo: ${e.toString()}',
      );
    }
  }

  // ==========================================================================
  // ASIGNACIÓN Y GESTIÓN DE AUDITORES
  // ==========================================================================

  /// Obtiene auditores disponibles
  Future<List<UserModel>> getAuditors() async {
    try {
      print('🔍 [GET_AUDITORS] Obteniendo lista de auditores...');

      final response = await _supabase
          .from('users')
          .select('id, name, email, role')
          .or('role.eq.auditor_junior,role.eq.auditor_senior');

      final auditors = (response as List)
          .map<UserModel>(
            (data) => UserModel(
              id: data['id'],
              name: data['name'],
              email: data['email'],
              role: UserModel.roleFromString(data['role']),
              biometricEnabled: false,
            ),
          )
          .toList();

      print('✅ [GET_AUDITORS] ${auditors.length} auditores encontrados');
      return auditors;
    } catch (e) {
      print('⚠️ [GET_AUDITORS] Error: $e');
      print('⚠️ [GET_AUDITORS] Retornando lista vacía por ahora');

      // Retornar lista vacía en lugar de fallar
      return [];
    }
  }

  /// Asigna un riesgo a un usuario específico
  Future<void> assignRiskToUser(String riskId, UserModel user) async {
    try {
      print('🔄 [ASSIGN_RISK] Asignando riesgo $riskId a ${user.name}');

      await _supabase
          .from('risks')
          .update({
            'assigned_user_id': user.id,
            'assigned_user_name': user.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', riskId);

      print('✅ [ASSIGN_RISK] Riesgo asignado exitosamente');
    } catch (e) {
      print('❌ [ASSIGN_RISK] Error: $e');
      throw RiskServiceException(
        'ASSIGN_RISK_ERROR',
        'Error al asignar el riesgo: ${e.toString()}',
      );
    }
  }

  // ==========================================================================
  // ELIMINACIÓN
  // ==========================================================================

  // ==========================================================================
  // ESTADÍSTICAS
  // ==========================================================================

  /// Obtiene estadísticas del dashboard
  Future<Map<String, dynamic>> getDashboardStats({String? userId}) async {
    try {
      print('📊 [DASHBOARD_STATS] Obteniendo estadísticas...');

      final response = await _supabase.rpc(
        'get_dashboard_stats',
        params: userId != null ? {'user_id_param': userId} : {},
      );

      print('✅ [DASHBOARD_STATS] Estadísticas obtenidas');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('❌ [DASHBOARD_STATS] Error: $e');
      throw RiskServiceException(
        'STATS_ERROR',
        'Error al cargar las estadísticas: ${e.toString()}',
      );
    }
  }

  // ==========================================================================
  // COMENTARIOS
  // ==========================================================================

  /// Agrega un comentario a un riesgo
  Future<void> addRiskComment(
    String riskId,
    String comment, {
    String type = 'general',
  }) async {
    try {
      print('💬 [ADD_COMMENT] Agregando comentario al riesgo: $riskId');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw RiskServiceException(
          'NOT_AUTHENTICATED',
          'Debes estar autenticado para comentar',
        );
      }

      await _supabase.from('risk_comments').insert({
        'risk_id': riskId,
        'user_id': currentUser.id,
        'comment': comment,
        'comment_type': type,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ [ADD_COMMENT] Comentario agregado exitosamente');
    } catch (e) {
      print('❌ [ADD_COMMENT] Error: $e');
      throw RiskServiceException(
        'ADD_COMMENT_ERROR',
        'Error al agregar el comentario: ${e.toString()}',
      );
    }
  }

  /// Obtiene comentarios de un riesgo
  Future<List<Map<String, dynamic>>> getRiskComments(String riskId) async {
    try {
      print('💬 [GET_COMMENTS] Obteniendo comentarios del riesgo: $riskId');

      final response = await _supabase
          .from('risk_comments')
          .select('''
            *,
            users:user_id (name, email)
          ''')
          .eq('risk_id', riskId)
          .order('created_at', ascending: true);

      print('✅ [GET_COMMENTS] Comentarios obtenidos');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ [GET_COMMENTS] Error: $e');
      throw RiskServiceException(
        'GET_COMMENTS_ERROR',
        'Error al cargar los comentarios: ${e.toString()}',
      );
    }
  }

  // ==========================================================================
  // ELIMINACIÓN DE RIESGOS
  // ==========================================================================

  /// Elimina un riesgo de la base de datos (solo para gerentes)
  Future<void> deleteRisk(String riskId) async {
    try {
      print('🗑️ [DELETE_RISK] Eliminando riesgo: $riskId');

      // Verificar que el usuario actual sea gerente
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw RiskServiceException(
          'DELETE_RISK_UNAUTHORIZED',
          'Usuario no autenticado',
        );
      }

      // Obtener información del usuario para verificar rol
      final userResponse = await _supabase
          .from('users')
          .select('role')
          .eq('id', currentUser.id)
          .single();

      if (userResponse['role'] != 'gerente_auditoria') {
        throw RiskServiceException(
          'DELETE_RISK_FORBIDDEN',
          'Solo los gerentes pueden eliminar riesgos',
        );
      }

      // Eliminar el riesgo
      await _supabase
          .from('risks')
          .delete()
          .eq('id', riskId);

      print('✅ [DELETE_RISK] Riesgo eliminado exitosamente: $riskId');
    } catch (e) {
      print('❌ [DELETE_RISK] Error: $e');
      if (e is RiskServiceException) {
        rethrow;
      }
      throw RiskServiceException(
        'DELETE_RISK_ERROR',
        'Error al eliminar el riesgo: ${e.toString()}',
      );
    }
  }
}
