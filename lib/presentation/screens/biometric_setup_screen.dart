import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_gobiernoti/presentation/providers/auth_provider.dart';
import 'package:app_gobiernoti/data/services/biometric_service.dart';
import 'package:app_gobiernoti/core/locator.dart';

class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  final BiometricService _biometricService = locator<BiometricService>();
  bool _isLoading = false;
  bool _isDeviceCapable = false; // Para saber si el hardware existe

  @override
  void initState() {
    super.initState();
    _checkDeviceCapability();
  }

  Future<void> _checkDeviceCapability() async {
    final isCapable = await _biometricService.hasBiometrics();
    if (mounted) {
      setState(() {
        _isDeviceCapable = isCapable;
      });
    }
  }

  Future<void> _enableBiometric() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Usamos el nuevo método del provider
    final result = await authProvider.enableBiometrics();

    if (mounted) {
      if (result['success'] == true) {
        _showSuccess('¡Acceso biométrico habilitado exitosamente!');
      } else {
        _showError(result['message'] ?? 'No se pudo habilitar la biometría');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _disableBiometric() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Usamos el nuevo método del provider
    final result = await authProvider.disableBiometrics();

    if (mounted) {
      if (result['success'] == true) {
        _showSuccess('Acceso biométrico deshabilitado.');
      } else {
        _showError(result['message'] ?? 'No se pudo deshabilitar la biometría');
      }
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
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
        //backgroundColor: Theme.of(context).colorScheme.inversePrimary, // Quitado para usar el tema
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          // El estado 'isBiometricEnabled' ahora viene del provider
          final isEnabled = authProvider.hasBiometricData;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card de Estado del Dispositivo
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
                        if (_isDeviceCapable) ...[
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Expanded(child: Text('Dispositivo compatible')),
                            ],
                          ),
                        ] else ...[
                          const Row(
                            children: [
                              Icon(Icons.error, color: Colors.red),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No hay biometría disponible en este dispositivo',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Card de Estado Actual
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
                              isEnabled ? Icons.lock_open : Icons.lock,
                              color: isEnabled ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEnabled
                                  ? 'Acceso biométrico habilitado'
                                  : 'Acceso biométrico deshabilitado',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Botones de acción
                if (_isDeviceCapable) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : (isEnabled ? _disableBiometric : _enableBiometric),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(isEnabled ? Icons.lock : Icons.fingerprint),
                      label: Text(
                        _isLoading
                            ? 'Procesando...'
                            : (isEnabled
                                  ? 'Deshabilitar Biometría'
                                  : 'Habilitar Biometría'),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: isEnabled
                            ? Colors.red
                            : Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ... (Tu Card de Información de seguridad)
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Información de Seguridad',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Colors.blue.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Al habilitar, se guardará un token seguro en el llavero de tu dispositivo.\n'
                          '• Este token se desbloquea con tu huella/rostro para iniciar sesión.\n'
                          '• Tus datos biométricos nunca salen de tu dispositivo.',
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
