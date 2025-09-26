// lib/data/models/user_model.dart

enum UserRole {
  auditorJunior,
  auditorSenior,
  gerenteAuditoria,
  socioAuditoria,
  especialistaTI,
  unknown // Rol por defecto
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  // Helper para convertir un string a un UserRole
  static UserRole roleFromString(String roleString) {
    switch (roleString) {
      case 'Auditor Junior':
        return UserRole.auditorJunior;
      case 'Auditor Senior':
        return UserRole.auditorSenior;
      case 'Gerente de Auditoría':
        return UserRole.gerenteAuditoria;
      case 'Socio de Auditoría':
        return UserRole.socioAuditoria;
      case 'Especialista en TI':
        return UserRole.especialistaTI;
      default:
        return UserRole.unknown;
    }
  }
}