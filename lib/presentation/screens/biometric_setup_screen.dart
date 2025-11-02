import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../providers/auth_provider.dart';
import '../../data/services/biometric_service.dart';

class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isLoading = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await _biometricService.hasBiometrics();
      if (isAvailable) {
        final biometrics = await _biometricService.getAvailableBiometrics();
        setState(() {
          _availableBiometrics = biometrics;
        });
      }
    } catch (e) {
      _showError('Error al verificar biometría disponible');
    }
  }

  Future<void> _enableBiometric() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated) {
      _showError('Debes estar autenticado para configurar biometría');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Verificar que hay biometría disponible
      if (_availableBiometrics.isEmpty) {
        _showError('No hay métodos biométricos disponibles en este dispositivo');
        return;
      }

      // 2. Solicitar autenticación biométrica
      final reason = _getBiometricReason();
      final isAuthenticated = await _biometricService.authenticate(reason);

      if (isAuthenticated) {
        // 3. Habilitar en Supabase
        final success = await authProvider.enableBiometric();
        
        if (success) {
          _showSuccess('¡Autenticación biométrica habilitada exitosamente!');
          Navigator.of(context).pop(true);
        } else {
          _showError('Error al habilitar autenticación biométrica');
        }
      } else {
        _showError('Autenticación biométrica cancelada');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _disableBiometric() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    setState(() => _isLoading = true);

    try {
      final success = await authProvider.disableBiometric();
      
      if (success) {
        _showSuccess('Autenticación biométrica deshabilitada');
        Navigator.of(context).pop(false);
      } else {
        _showError('Error al deshabilitar autenticación biométrica');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getBiometricReason() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Configura el reconocimiento facial para acceso rápido';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Configura la huella dactilar para acceso rápido';
    } else {
      return 'Configura la autenticación biométrica para acceso rápido';
    }
  }

  String _getBiometricTypeText() {
    List<String> types = [];
    if (_availableBiometrics.contains(BiometricType.face)) {
      types.add('Reconocimiento facial');
    }
    if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      types.add('Huella dactilar');
    }
    if (_availableBiometrics.contains(BiometricType.iris)) {
      types.add('Reconocimiento de iris');
    }
    
    return types.isNotEmpty ? types.join(', ') : 'Biometría genérica';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración Biométrica'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Información del usuario
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Usuario Actual',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Nombre: ${authProvider.currentUser?.name ?? 'N/A'}'),
                        Text('Email: ${authProvider.currentUser?.email ?? 'N/A'}'),
                        Text('Rol: ${authProvider.currentUser?.role.toString().split('.').last ?? 'N/A'}'),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Estado de biometría disponible
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biometría Disponible',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (_availableBiometrics.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_getBiometricTypeText())),
                            ],
                          ),
                        ] else ...[
                          const Row(
                            children: [
                              Icon(Icons.error, color: Colors.red),
                              SizedBox(width: 8),
                              Expanded(child: Text('No hay biometría disponible')),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Estado actual de configuración
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estado Actual',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              authProvider.isBiometricEnabled 
                                  ? Icons.lock_open 
                                  : Icons.lock,
                              color: authProvider.isBiometricEnabled 
                                  ? Colors.green 
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              authProvider.isBiometricEnabled 
                                  ? 'Autenticación biométrica habilitada'
                                  : 'Autenticación biométrica deshabilitada',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Botones de acción
                if (_availableBiometrics.isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : (
                        authProvider.isBiometricEnabled 
                            ? _disableBiometric 
                            : _enableBiometric
                      ),
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              authProvider.isBiometricEnabled 
                                  ? Icons.lock 
                                  : Icons.fingerprint,
                            ),
                      label: Text(
                        _isLoading 
                            ? 'Procesando...'
                            : (authProvider.isBiometricEnabled 
                                ? 'Deshabilitar Biometría' 
                                : 'Habilitar Biometría'),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: authProvider.isBiometricEnabled 
                            ? Colors.red 
                            : Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Información de seguridad
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'Información de Seguridad',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• La biometría se asocia únicamente a tu cuenta\n'
                          '• Solo tú podrás acceder con tu biometría\n'
                          '• Puedes deshabilitar esta función en cualquier momento\n'
                          '• Los datos biométricos se almacenan de forma segura',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}