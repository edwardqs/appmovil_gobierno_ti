import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';
import '../../core/locator.dart';

// ============================================================================
// ENUM PARA ESTADOS DE AUTENTICACIÓN
// ============================================================================

enum AuthStatus {
  uninitialized,
  authenticated,
  unauthenticated,
  loading,
  error,
}

// ============================================================================
// AUTH PROVIDER
// ============================================================================

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = locator<AuthService>();

  // Estados privados
  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _user;
  String? _errorMessage;
  bool _hasBiometricData = false;

  // Getters públicos
  AuthStatus get status => _status;
  UserModel? get currentUser => _user;
  String? get errorMessage => _errorMessage;
  bool get hasBiometricData => _hasBiometricData;

  // Constructor
  AuthProvider() {
    _initializeApp();
  }

  // ==========================================================================
  // INICIALIZACIÓN
  // ==========================================================================

  /// Inicializa la app, comprueba la sesión y el estado biométrico
  Future<void> _initializeApp() async {
    print('🚀 [AUTH_PROVIDER] Inicializando aplicación...');

    _status = AuthStatus.loading;
    notifyListeners();

    // Verificar estado biométrico
    await checkBiometricStatus();
    print('🔐 [AUTH_PROVIDER] Estado biométrico: $_hasBiometricData');

    // Verificar si hay sesión activa
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        print('✅ [AUTH_PROVIDER] Sesión activa encontrada: ${user.email}');
        _user = user;
        _status = AuthStatus.authenticated;
      } else {
        print('ℹ️ [AUTH_PROVIDER] No hay sesión activa');
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      print('❌ [AUTH_PROVIDER] Error al verificar sesión: $e');
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
    print('✅ [AUTH_PROVIDER] Inicialización completada. Estado: $_status');
  }

  // ==========================================================================
  // AUTENTICACIÓN CON EMAIL/PASSWORD
  // ==========================================================================

  /// Inicia sesión con Email y Contraseña
  Future<void> login(String email, String password) async {
    print('🔐 [AUTH_PROVIDER] Iniciando login con email: $email');

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // ✅ CORREGIDO: Usa el método login() del servicio
      _user = await _authService.login(email, password);
      _status = AuthStatus.authenticated;

      print('✅ [AUTH_PROVIDER] Login exitoso: ${_user!.email}');

      // Sincroniza el estado biométrico
      await checkBiometricStatus();
      if (_user != null && _hasBiometricData) {
        _user = _user!.copyWith(biometricEnabled: true);
      }
    } on AuthServiceException catch (e) {
      print('❌ [AUTH_PROVIDER] Error de AuthService: ${e.message}');
      _status = AuthStatus.error;
      _errorMessage = e.message;
    } catch (e) {
      print('❌ [AUTH_PROVIDER] Error inesperado en login: $e');
      _status = AuthStatus.error;
      _errorMessage = 'Error inesperado: ${e.toString()}';
    }

    notifyListeners();
  }

  // ==========================================================================
  // CIERRE DE SESIÓN
  // ==========================================================================

  /// Cierra la sesión
  Future<void> logout() async {
    print('🔐 [AUTH_PROVIDER] Iniciando logout...');

    _status = AuthStatus.loading;
    notifyListeners();

    try {
      // ✅ CORREGIDO: Usa logout() en lugar de signOut()
      await _authService.logout();

      _user = null;
      _status = AuthStatus.unauthenticated;

      print('✅ [AUTH_PROVIDER] Logout exitoso');
    } catch (e) {
      print('❌ [AUTH_PROVIDER] Error en logout: $e');
      // Aunque falle, limpiamos el estado local
      _user = null;
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  // ==========================================================================
  // AUTENTICACIÓN BIOMÉTRICA
  // ==========================================================================

  /// Inicia sesión con Biometría
  Future<void> loginWithBiometrics() async {
    print('🔐 [AUTH_PROVIDER] Iniciando loginWithBiometrics...');
    print('🔐 [AUTH_PROVIDER] Estado actual: $_status');

    // Evitar múltiples intentos simultáneos
    if (_status == AuthStatus.loading) {
      print('⚠️ [AUTH_PROVIDER] Login biométrico ya en progreso, ignorando...');
      return;
    }

    print('🔄 [AUTH_PROVIDER] Cambiando estado a loading...');
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      print(
        '🔐 [AUTH_PROVIDER] Llamando a _authService.loginWithBiometrics()...',
      );

      // ✅ CORREGIDO: Usa el método correcto del servicio
      _user = await _authService.loginWithBiometrics();

      if (_user != null) {
        print(
          '✅ [AUTH_PROVIDER] Login biométrico exitoso, usuario: ${_user!.email}',
        );
        _status = AuthStatus.authenticated;
      } else {
        print('🚫 [AUTH_PROVIDER] Login biométrico cancelado (usuario null)');
        _status = AuthStatus.unauthenticated;
        _errorMessage = "Autenticación biométrica cancelada";
      }
    } on BiometricAuthException catch (e) {
      print('❌ [AUTH_PROVIDER] Error BiometricAuthException: ${e.message}');
      _status = AuthStatus.error;

      // Mejorar mensajes de error específicos
      String errorMessage = e.message;

      if (e.code == 'CREDENTIALS_NOT_FOUND') {
        errorMessage =
        "Credenciales biométricas no encontradas. Inicia sesión manualmente.";
      } else if (e.code == 'SESSION_EXPIRED' ||
          e.code == 'CREDENTIALS_EXPIRED') {
        // ✅ CORRECCIÓN: Mensaje actualizado para guiar al usuario
        errorMessage =
        "Sesión biométrica expirada. Inicia sesión manually para reactivarla.";
      } else if (e.code == 'DEVICE_MISMATCH') {
        errorMessage =
        "Este dispositivo no coincide con el registrado. Inicia sesión manualmente.";
      } else if (e.code == 'AUTH_FAILED') {
        errorMessage = "Autenticación biométrica cancelada o fallida.";
      }

      _errorMessage = errorMessage;
    } catch (e) {
      print('❌ [AUTH_PROVIDER] Error inesperado en loginWithBiometrics: $e');
      _status = AuthStatus.error;
      _errorMessage = 'Error en autenticación biométrica: ${e.toString()}';
    }

    print('🔄 [AUTH_PROVIDER] Estado final: $_status');
    print('🔄 [AUTH_PROVIDER] Notificando listeners...');
    notifyListeners();
    print('✅ [AUTH_PROVIDER] loginWithBiometrics completado');
  }

  // ==========================================================================
  // GESTIÓN DE BIOMETRÍA
  // ==========================================================================

  /// Habilita la biometría
  Future<Map<String, dynamic>> enableBiometrics() async {
    print('🔐 [AUTH_PROVIDER] Habilitando biometría...');
    print('🔐 [AUTH_PROVIDER] Usuario actual: ${_user?.email ?? "no hay usuario"}');

    // ✅ CORREGIDO: Usa el método correcto del servicio
    print('🔐 [AUTH_PROVIDER] Llamando a _authService.enableBiometricForCurrentUser()...');
    final result = await _authService.enableBiometricForCurrentUser();
    print('🔐 [AUTH_PROVIDER] Resultado del servicio: $result');

    if (result['success'] == true) {
      print('✅ [AUTH_PROVIDER] Biometría habilitada exitosamente');
      _hasBiometricData = true;

      if (_user != null) {
        _user = _user!.copyWith(biometricEnabled: true);
      }
    } else {
      print(
        '❌ [AUTH_PROVIDER] Error al habilitar biometría: ${result['message']}',
      );
      _errorMessage = result['message'];
    }

    notifyListeners();
    return result;
  }

  /// Deshabilita la biometría
  Future<Map<String, dynamic>> disableBiometrics() async {
    print('🔐 [AUTH_PROVIDER] Deshabilitando biometría...');

    // ✅ CORREGIDO: Usa el método correcto del servicio
    final result = await _authService.disableBiometricForCurrentUser();

    if (result['success'] == true) {
      print('✅ [AUTH_PROVIDER] Biometría deshabilitada exitosamente');
      _hasBiometricData = false;

      if (_user != null) {
        _user = _user!.copyWith(biometricEnabled: false);
      }
    } else {
      print(
        '❌ [AUTH_PROVIDER] Error al deshabilitar biometría: ${result['message']}',
      );
      _errorMessage = result['message'];
    }

    notifyListeners();
    return result;
  }

  /// Comprueba el estado del indicador biométrico
  Future<void> checkBiometricStatus() async {
    print('🔍 [AUTH_PROVIDER] Verificando estado biométrico...');

    // ✅ CORREGIDO: Usa el método correcto del servicio
    _hasBiometricData = await _authService.checkBiometricStatus();

    print('🔍 [AUTH_PROVIDER] Biometría habilitada: $_hasBiometricData');
    notifyListeners();
  }

  /// Obtiene la información del usuario biométrico almacenado
  Future<Map<String, String>?> getStoredBiometricUserInfo() async {
    print('🔍 [AUTH_PROVIDER] Obteniendo información biométrica almacenada...');
    return await _authService.getStoredBiometricUserInfo();
  }

  // ==========================================================================
  // REGISTRO DE USUARIO
  // ==========================================================================

  /// Registra un nuevo usuario
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String dni,
    String? phone,
    String? address,
  }) async {
    print('📝 [AUTH_PROVIDER] Iniciando registro para: $email');

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // ✅ CORREGIDO: Usa el método registerUser del servicio
      await _authService.registerUser(
        email: email,
        password: password,
        name: name,
        role: "auditor_junior", // Rol por defecto
        dni: dni,
        phone: phone,
        address: address,
      );

      print('✅ [AUTH_PROVIDER] Registro exitoso');

      // El registro no autentica automáticamente
      _status = AuthStatus.unauthenticated;
      notifyListeners();

      return true;
    } on AuthServiceException catch (e) {
      print('❌ [AUTH_PROVIDER] Error de AuthServiceException: ${e.message}');
      _status = AuthStatus.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } on UserProfileException catch (e) {
      print('❌ [AUTH_PROVIDER] Error de UserProfileException: ${e.message}');
      _status = AuthStatus.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      print('❌ [AUTH_PROVIDER] Error inesperado en registro: $e');
      _status = AuthStatus.error;
      _errorMessage = 'Error inesperado: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // ==========================================================================
  // UTILIDADES
  // ==========================================================================

  /// Limpia el mensaje de error
  void clearError() {
    print('🧹 [AUTH_PROVIDER] Limpiando error...');

    _errorMessage = null;

    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }
}
