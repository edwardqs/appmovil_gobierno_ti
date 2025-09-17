import 'package:flutter/foundation.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/audit_service.dart';

// ChangeNotifier notifica a los widgets cuando el estado de la autenticación cambia.
class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final AuditService _auditService = AuditService();

  AuthProvider(this._authService);

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Método para iniciar sesión
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null; // Limpiar error previo
    notifyListeners();

    bool success = false;
    try {
      // Asumimos que _authService.login puede lanzar una excepción o devolver false
      // También asumimos que si _authService.login devuelve false, es un fallo de credenciales
      // y si lanza una excepción, es otro tipo de error.
      success = await _authService.login(email, password);
      if (success) {
        _isAuthenticated = true;
        _errorMessage = null;
        _auditService.logLoginAttempt(email, success: true);
      } else {
        _isAuthenticated = false;
        // Podrías intentar obtener un mensaje más específico del _authService si lo provee
        _errorMessage = "Email o contraseña incorrectos.";
        _auditService.logLoginAttempt(email, success: false);
      }
    } catch (e) {
      _isAuthenticated = false;
      _errorMessage = "Ocurrió un error inesperado al intentar iniciar sesión.";
      _auditService.logLoginAttempt(email, success: false, error: e.toString());
      // Podrías registrar el error 'e' para depuración: print(e);
      success = false;
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }

  // Método para cerrar sesión
  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _isLoading = false; // Asegurarse que isLoading esté en false
    _errorMessage = null; // Limpiar errores al hacer logout
    notifyListeners(); // Notifica a la UI para redirigir al login
  }
}