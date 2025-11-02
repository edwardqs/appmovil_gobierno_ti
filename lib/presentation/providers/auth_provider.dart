// lib/presentation/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart'; // <-- 1. IMPORTAR
import '../../data/services/auth_service.dart';
import '../../data/services/audit_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final AuditService _auditService = AuditService();

  AuthProvider(this._authService) {
    checkBiometricData();
  }

  // ▼▼▼ 2. ESTADOS MODIFICADOS ▼▼▼
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  bool get isAuthenticated => _currentUser != null;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isBiometricEnabled = false;
  bool get isBiometricEnabled => _isBiometricEnabled;

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
        
        // ✅ AGREGADO: Actualizar estado biométrico después del login
        print('🔍 AuthProvider: Llamando checkBiometricData() después del login exitoso');
        await checkBiometricData();
        print('🔍 AuthProvider: checkBiometricData() completado después del login');
        
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

  bool _hasBiometricData = false;
  bool get hasBiometricDataValue => _hasBiometricData;

  Future<void> checkBiometricData() async {
    print('🔍 AuthProvider: checkBiometricData() iniciado');
    _hasBiometricData = await _authService.hasBiometricData();
    print('🔍 AuthProvider: _hasBiometricData = $_hasBiometricData');
    notifyListeners();
    print('🔍 AuthProvider: notifyListeners() llamado');
  }

  // ▼▼▼ 4. MÉTODO LOGOUT MODIFICADO ▼▼▼
  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    _isBiometricEnabled = false;
    notifyListeners();
  }

  // Método para establecer usuario actual (usado por autenticación biométrica)
  void setCurrentUser(UserModel user) {
    _currentUser = user;
    _isBiometricEnabled = user.biometricEnabled;
    _errorMessage = null;
    notifyListeners();
  }

  // ▼▼▼ 5. MÉTODOS DE BIOMETRÍA ▼▼▼
  Future<bool> enableBiometric() async {
    try {
      final result = await _authService.enableBiometricForCurrentUser();
      
      if (result['success'] == true) {
        _isBiometricEnabled = true;
        
        // Actualizar el usuario actual si existe
        if (_currentUser != null) {
          _currentUser = UserModel(
            id: _currentUser!.id,
            name: _currentUser!.name,
            email: _currentUser!.email,
            role: _currentUser!.role,
            biometricEnabled: true,
            dni: _currentUser!.dni,
            phone: _currentUser!.phone,
            address: _currentUser!.address,
          );
        }
        
        notifyListeners();
        checkBiometricData(); // Actualiza el estado de hasBiometricData
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> disableBiometric() async {
    try {
      final result = await _authService.disableBiometricForCurrentUser();
      
      if (result['success'] == true) {
        _isBiometricEnabled = false;
        
        // Actualizar el usuario actual si existe
        if (_currentUser != null) {
          _currentUser = UserModel(
            id: _currentUser!.id,
            name: _currentUser!.name,
            email: _currentUser!.email,
            role: _currentUser!.role,
            biometricEnabled: false,
            dni: _currentUser!.dni,
            phone: _currentUser!.phone,
            address: _currentUser!.address,
          );
        }
        
        notifyListeners();
        checkBiometricData(); // Actualiza el estado de hasBiometricData
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  // Verificar si hay datos biométricos guardados
  Future<bool> hasBiometricData() async {
    return await _authService.hasBiometricData();
  }

  // Verificar disponibilidad de biometría en el dispositivo
  Future<bool> isBiometricAvailable() async {
    return await _authService.isBiometricAvailable();
  }

  // Método para actualizar el estado biométrico desde otras pantallas
  void updateBiometricStatus(bool enabled) {
    _isBiometricEnabled = enabled;
    
    // También actualizar el usuario actual si existe
    if (_currentUser != null) {
      _currentUser = UserModel(
        id: _currentUser!.id,
        name: _currentUser!.name,
        email: _currentUser!.email,
        role: _currentUser!.role,
        biometricEnabled: enabled,
        dni: _currentUser!.dni,
        phone: _currentUser!.phone,
        address: _currentUser!.address,
      );
    }
    
    notifyListeners();
  }
}