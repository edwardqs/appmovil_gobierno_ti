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
  });

  // Helper para convertir un string a un UserRole
  static UserRole roleFromString(String roleString) {
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
      case 'gerente_auditoria':
      case 'gerenteAuditoria': // Formato camelCase de la base de datos
      case 'gerente': // ✅ AGREGADO: Formato usado en la base de datos
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
        return 'gerente_auditoria';
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