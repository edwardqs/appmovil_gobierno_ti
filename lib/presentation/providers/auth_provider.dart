import 'package:flutter/material.dart';
import 'package:app_gobiernoti/data/models/user_model.dart';
import 'package:app_gobiernoti/data/services/auth_service.dart';
import 'package:app_gobiernoti/core/locator.dart';

// 1. Enum para manejar los estados de autenticación
enum AuthStatus {
  uninitialized,
  authenticated,
  unauthenticated,
  loading,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = locator<AuthService>();

  // 2. Estados privados
  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _user;
  String? _errorMessage;
  bool _hasBiometricData = false; // Solo para la UI (saber si mostrar el botón)

  // 3. Getters públicos
  AuthStatus get status => _status;
  UserModel? get currentUser => _user;
  String? get errorMessage => _errorMessage;
  bool get hasBiometricData => _hasBiometricData;

  // 4. Constructor
  AuthProvider() {
    _initializeApp();
  }

  /// Inicializa la app, comprueba la sesión y el estado biométrico
  Future<void> _initializeApp() async {
    _status = AuthStatus.loading;
    notifyListeners();

    // Comprueba si el indicador biométrico está habilitado
    await checkBiometricStatus();

    // Al iniciar, asumimos que no está autenticado.
    // El router se encargará de redirigir a /login
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Inicia sesión con Email y Contraseña
  Future<void> login(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Usamos el nuevo método del servicio
      _user = await _authService.loginWithEmail(email, password);
      _status = AuthStatus.authenticated;

      // Sincroniza el estado biométrico (si está habilitado en el dispositivo)
      await checkBiometricStatus();
      if (_user != null) {
        _user = _user!.copyWith(biometricEnabled: _hasBiometricData);
      }
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
    }
    notifyListeners();
  }

  /// Cierra la sesión
  Future<void> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();

    await _authService.signOut();
    _user = null;
    _status = AuthStatus.unauthenticated;
    // No cambiamos _hasBiometricData, el token sigue guardado
    // para que el usuario pueda volver a iniciar sesión con huella.
    notifyListeners();
  }

  /// Inicia sesión con Biometría
  Future<void> loginWithBiometrics() async {
    print('🔐 [AUTH_PROVIDER] Iniciando loginWithBiometrics...');
    print('🔐 [AUTH_PROVIDER] Estado actual: $_status');
    
    // Evitar múltiples intentos simultáneos
    if (_status == AuthStatus.loading) {
      print('⚠️ [AUTH_PROVIDER] Intento de login biométrico ya en progreso, ignorando...');
      return;
    }

    print('🔄 [AUTH_PROVIDER] Cambiando estado a loading...');
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🔐 [AUTH_PROVIDER] Llamando a _authService.loginWithBiometrics()...');
      _user = await _authService.loginWithBiometrics();
      
      if (_user != null) {
        print('✅ [AUTH_PROVIDER] Login biométrico exitoso, usuario: ${_user!.email}');
        _status = AuthStatus.authenticated;
      } else {
        // Si loginWithBiometrics retorna null, significa que la autenticación fue cancelada
        print('🚫 [AUTH_PROVIDER] Login biométrico cancelado (usuario null)');
        _status = AuthStatus.unauthenticated;
        _errorMessage = "Autenticación biométrica cancelada";
      }
    } catch (e) {
      print('❌ [AUTH_PROVIDER] Error en loginWithBiometrics: $e');
      _status = AuthStatus.error;
      String errorMessage = e.toString().replaceFirst("Exception: ", "");
      
      // Mejorar mensajes de error específicos para biometría
      if (errorMessage.contains("BiometricAuthException")) {
        errorMessage = errorMessage.replaceFirst("BiometricAuthException: ", "");
      }
      if (errorMessage.contains("CREDENTIALS_NOT_FOUND")) {
        errorMessage = "Credenciales biométricas no encontradas. Inicia sesión manualmente.";
      } else if (errorMessage.contains("SESSION_EXPIRED") || errorMessage.contains("CREDENTIALS_EXPIRED")) {
        errorMessage = "Credenciales biométricas expiradas. Inicia sesión manualmente.";
      } else if (errorMessage.contains("INVALID_SESSION")) {
        errorMessage = "Sesión biométrica inválida. Inicia sesión manualmente.";
      }
      
      _errorMessage = errorMessage;
      print('❌ [AUTH_PROVIDER] Error procesado: $errorMessage');
    }
    
    print('🔄 [AUTH_PROVIDER] Estado final: $_status');
    print('🔄 [AUTH_PROVIDER] Notificando listeners...');
    notifyListeners();
    print('✅ [AUTH_PROVIDER] loginWithBiometrics completado');
  }

  /// Registra un nuevo usuario
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String dni,
    String? phone,
    String? address,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // El registro ahora NO devuelve un usuario logueado
      // Solo registra. El usuario debe confirmar su email (si está habilitado)
      // y luego hacer login.
      await _authService.registerUser(
        email: email,
        password: password,
        name: name,
        role: "auditor_junior", // Rol por defecto al registrarse
        dni: dni,
        phone: phone,
        address: address,
      );
      _status = AuthStatus.unauthenticated; // Vuelve a "no autenticado"
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      notifyListeners();
      return false;
    }
  }

  /// Habilita la biometría
  Future<Map<String, dynamic>> enableBiometrics() async {
    // No ponemos loading, es una acción en segundo plano
    final result = await _authService.enableBiometricForCurrentUser();

    if (result['success'] == true) {
      _hasBiometricData = true;
      if (_user != null) {
        _user = _user!.copyWith(biometricEnabled: true);
      }
    } else {
      _errorMessage = result['message'];
    }
    notifyListeners();
    return result;
  }

  /// Deshabilita la biometría
  Future<Map<String, dynamic>> disableBiometrics() async {
    // No ponemos loading
    final result = await _authService.disableBiometricForCurrentUser();

    if (result['success'] == true) {
      _hasBiometricData = false;
      if (_user != null) {
        _user = _user!.copyWith(biometricEnabled: false);
      }
    } else {
      _errorMessage = result['message'];
    }
    notifyListeners();
    return result;
  }

  /// Comprueba el estado del indicador biométrico (de SharedPreferences)
  Future<void> checkBiometricStatus() async {
    _hasBiometricData = await _authService.checkBiometricStatus();
    notifyListeners();
  }

  /// Limpia el mensaje de error
  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }
}
