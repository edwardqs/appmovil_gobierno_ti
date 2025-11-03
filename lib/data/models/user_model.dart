// lib/data/models/user_model.dart

enum UserRole {
  auditorJunior,
  auditorSenior,
  gerenteAuditoria,
  unknown, // Rol por defecto
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole? role; // Nullable porque puede no tener rol asignado
  final bool biometricEnabled;
  final String? biometricToken;
  final String? deviceId;
  final String? dni;
  final String? phone;
  final String? address;
  
  // ▼▼▼ NUEVAS PROPIEDADES PARA ESTADÍSTICAS DE RIESGOS ▼▼▼
  final int? totalRisksAssigned;
  final int? openRisks;
  final int? inProgressRisks;
  final int? pendingReviewRisks;
  final int? closedRisks;
  // ▲▲▲ FIN DE NUEVAS PROPIEDADES ▲▲▲

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.role, // Opcional
    this.biometricEnabled = false,
    this.biometricToken,
    this.deviceId,
    this.dni,
    this.phone,
    this.address,
    // ▼▼▼ NUEVOS PARÁMETROS OPCIONALES ▼▼▼
    this.totalRisksAssigned,
    this.openRisks,
    this.inProgressRisks,
    this.pendingReviewRisks,
    this.closedRisks,
    // ▲▲▲ FIN DE NUEVOS PARÁMETROS ▲▲▲
  });

  // ▼▼▼ MÉTODO AÑADIDO (ESTA ES LA CORRECCIÓN PRINCIPAL) ▼▼▼
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    bool? biometricEnabled,
    String? biometricToken,
    String? deviceId,
    String? dni,
    String? phone,
    String? address,
    // ▼▼▼ NUEVOS PARÁMETROS PARA ESTADÍSTICAS ▼▼▼
    int? totalRisksAssigned,
    int? openRisks,
    int? inProgressRisks,
    int? pendingReviewRisks,
    int? closedRisks,
    // ▲▲▲ FIN DE NUEVOS PARÁMETROS ▲▲▲
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricToken: biometricToken ?? this.biometricToken,
      deviceId: deviceId ?? this.deviceId,
      dni: dni ?? this.dni,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      // ▼▼▼ NUEVAS ASIGNACIONES ▼▼▼
      totalRisksAssigned: totalRisksAssigned ?? this.totalRisksAssigned,
      openRisks: openRisks ?? this.openRisks,
      inProgressRisks: inProgressRisks ?? this.inProgressRisks,
      pendingReviewRisks: pendingReviewRisks ?? this.pendingReviewRisks,
      closedRisks: closedRisks ?? this.closedRisks,
      // ▲▲▲ FIN DE NUEVAS ASIGNACIONES ▲▲▲
    );
  }
  // ▲▲▲ FIN DEL MÉTODO AÑADIDO ▲▲▲

  // ▼▼▼ NUEVO CONSTRUCTOR DE FÁBRICA AÑADIDO ▼▼▼
  /// Crea un UserModel desde un mapa (respuesta de Supabase)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Sin nombre',
      email: map['email'] ?? 'Sin email',
      role: roleFromString(map['role']),
      biometricEnabled: map['biometric_enabled'] ?? false,
      biometricToken: map['biometric_token'],
      deviceId: map['device_id'],
      dni: map['dni'],
      phone: map['phone'],
      address: map['address'],
    );
  }

  /// Crea un UserModel desde un mapa con estadísticas (respuesta de user_stats)
  factory UserModel.fromMapWithStats(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Sin nombre',
      email: map['email'] ?? 'Sin email',
      role: roleFromString(map['role']),
      biometricEnabled: map['biometric_enabled'] ?? false,
      biometricToken: map['biometric_token'],
      deviceId: map['device_id'],
      dni: map['dni'],
      phone: map['phone'],
      address: map['address'],
      // ▼▼▼ ESTADÍSTICAS DE RIESGOS ▼▼▼
      totalRisksAssigned: map['total_risks_assigned'] ?? 0,
      openRisks: map['open_risks'] ?? 0,
      inProgressRisks: map['in_progress_risks'] ?? 0,
      pendingReviewRisks: map['pending_review_risks'] ?? 0,
      closedRisks: map['closed_risks'] ?? 0,
      // ▲▲▲ FIN DE ESTADÍSTICAS ▲▲▲
    );
  }
  // ▲▲▲ FIN DEL CONSTRUCTOR DE FÁBRICA ▲▲▲


  // Helper para convertir un string a un UserRole
  static UserRole roleFromString(String? roleString) {
    // Acepta nullable
    switch (roleString) {
      case 'Auditor Junior':
      case 'auditor_junior':
      case 'auditorJunior': // Formato camelCase de la base de datos
        return UserRole.auditorJunior;
      case 'Auditor Senior':
      case 'auditor_senior':
      case 'auditorSenior': // Formato camelCase de la base de datos
        return UserRole.auditorSenior;
      case 'Gerente Auditor':
      case 'gerente_auditoria': // ✅ CORRECTO: Formato de la BD
      case 'gerenteAuditoria': // Formato camelCase de la base de datos
      case 'gerente':
        return UserRole.gerenteAuditoria;
      default:
        return UserRole.unknown;
    }
  }

  // Helper para convertir UserRole a string para Supabase
  static String roleToSupabase(UserRole role) {
    switch (role) {
      case UserRole.auditorJunior:
        return 'auditor_junior';
      case UserRole.auditorSenior:
        return 'auditor_senior';
      case UserRole.gerenteAuditoria:
        return 'gerente_auditoria'; // ✅ CORRECTO: Usar el formato de la BD
      case UserRole.unknown:
        return 'auditor_junior'; // Default fallback
    }
  }

  // Helper para convertir UserRole a string legible
  static String roleToDisplayString(UserRole role) {
    switch (role) {
      case UserRole.auditorJunior:
        return 'Auditor Junior';
      case UserRole.auditorSenior:
        return 'Auditor Senior';
      case UserRole.gerenteAuditoria:
        return 'Gerente de Auditoría';
      case UserRole.unknown:
        return 'Sin rol asignado';
    }
  }
}