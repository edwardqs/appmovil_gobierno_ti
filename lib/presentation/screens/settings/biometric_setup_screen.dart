// lib/presentation/screens/settings/biometric_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/services/auth_service.dart';

class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isBiometricAvailable = false;
  bool _hasBiometricData = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    final isAvailable = await _authService.isBiometricAvailable();
    final hasData = await _authService.hasBiometricData();
    
    setState(() {
      _isBiometricAvailable = isAvailable;
      _hasBiometricData = hasData;
    });
  }

  Future<void> _enableBiometric() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.enableBiometricForCurrentUser();
      
      if (result['success'] == true) {
        // Actualizar el estado del provider
        if (mounted) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          authProvider.updateBiometricStatus(true);
        }

        _showSuccessDialog(result['message']);
        await _checkBiometricStatus();
      } else {
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      _showErrorDialog('Error inesperado: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _disableBiometric() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.disableBiometricForCurrentUser();
      
      if (result['success'] == true) {
        // Actualizar el estado del provider
        if (mounted) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          authProvider.updateBiometricStatus(false);
        }

        _showSuccessDialog(result['message']);
        await _checkBiometricStatus();
      } else {
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      _showErrorDialog('Error inesperado: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Éxito'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('¿Estás seguro de que deseas deshabilitar la autenticación biométrica?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _disableBiometric();
            },
            child: const Text('Deshabilitar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración Biométrica'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.fingerprint,
                          size: 32,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Autenticación Biométrica',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'La autenticación biométrica te permite acceder a la aplicación usando tu huella dactilar o reconocimiento facial.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    _buildStatusSection(),
                    const SizedBox(height: 20),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estado actual:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              _isBiometricAvailable ? Icons.check_circle : Icons.cancel,
              color: _isBiometricAvailable ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              _isBiometricAvailable 
                ? 'Biometría disponible en el dispositivo'
                : 'Biometría no disponible en el dispositivo',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              _hasBiometricData ? Icons.check_circle : Icons.cancel,
              color: _hasBiometricData ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(
              _hasBiometricData 
                ? 'Biometría configurada'
                : 'Biometría no configurada',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (!_isBiometricAvailable) {
      return const Card(
        color: Colors.orange,
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'La biometría no está disponible en este dispositivo',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (!_hasBiometricData) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _enableBiometric,
              icon: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fingerprint),
              label: Text(_isLoading ? 'Registrando biometría...' : 'Registrar y Habilitar Biometría'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Al presionar este botón, se te pedirá que registres tu huella dactilar o rostro para habilitar el acceso rápido.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _showConfirmationDialog,
              icon: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fingerprint_outlined),
              label: Text(_isLoading ? 'Deshabilitando...' : 'Deshabilitar Biometría'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Información importante',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '• La biometría proporciona una forma rápida y segura de acceder a la aplicación.\n'
              '• Puedes habilitar o deshabilitar esta función en cualquier momento.\n'
              '• Si deshabilitas la biometría, deberás usar tu email y contraseña para iniciar sesión.\n'
              '• Los datos biométricos se almacenan de forma segura en tu dispositivo.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}