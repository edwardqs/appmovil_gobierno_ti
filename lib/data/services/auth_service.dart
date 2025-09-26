// lib/data/services/auth_service.dart

import '../models/user_model.dart';

class AuthService {
  // Simulación de base de datos de usuarios
  final List<Map<String, String>> _users = [
    {
      'id': '1',
      'name': 'Ana Torres',
      'email': 'auditor.jr@company.com',
      'password': 'password',
      'role': 'Auditor Junior',
    },
    // ▼▼▼ NUEVO USUARIO AÑADIDO ▼▼▼
    {
      'id': '3',
      'name': 'Luis Gomez',
      'email': 'auditor.sr@company.com',
      'password': 'password',
      'role': 'Auditor Senior',
    },
    {
      'id': '2',
      'name': 'Carlos Ramirez',
      'email': 'gerente.ti@company.com',
      'password': 'password',
      'role': 'Gerente de Auditoría',
    },
  ];

  Future<UserModel?> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    final userRecord = _users.firstWhere(
          (user) => user['email'] == email && user['password'] == password,
      orElse: () => {},
    );

    if (userRecord.isNotEmpty) {
      return UserModel(
        id: userRecord['id']!,
        name: userRecord['name']!,
        email: userRecord['email']!,
        role: UserModel.roleFromString(userRecord['role']!),
      );
    }
    return null;
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}