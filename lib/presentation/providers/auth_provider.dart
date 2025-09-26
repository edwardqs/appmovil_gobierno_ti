// lib/presentation/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart'; // <-- 1. IMPORTAR
import '../../data/services/auth_service.dart';
import '../../data/services/audit_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final AuditService _auditService = AuditService();

  AuthProvider(this._authService);

  // ▼▼▼ 2. ESTADOS MODIFICADOS ▼▼▼
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  bool get isAuthenticated => _currentUser != null;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ▼▼▼ 3. MÉTODO LOGIN MODIFICADO ▼▼▼
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.login(email, password);

      if (user != null) {
        _currentUser = user;
        _errorMessage = null;
        _auditService.logLoginAttempt(email, success: true);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _currentUser = null;
        _errorMessage = "Email o contraseña incorrectos.";
        _auditService.logLoginAttempt(email, success: false);
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _currentUser = null;
      _errorMessage = "Ocurrió un error inesperado.";
      _auditService.logLoginAttempt(email, success: false, error: e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ▼▼▼ 4. MÉTODO LOGOUT MODIFICADO ▼▼▼
  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }
}