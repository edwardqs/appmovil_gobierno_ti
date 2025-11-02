import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/biometric_service.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _dniController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  final AuthService _authService = AuthService();
  final BiometricService _biometricService = BiometricService();
  
  bool _isLoading = false;
  bool _enableBiometric = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await _biometricService.hasBiometrics();
      setState(() {
        _biometricAvailable = isAvailable;
      });
    } catch (e) {
      setState(() {
        _biometricAvailable = false;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Crear el nombre completo
      final fullName = '${_nameController.text.trim()} ${_lastNameController.text.trim()}';
      
      String? deviceId;
      String? biometricHash;
      
      // Si se habilitó biometría, obtener datos biométricos
      if (_enableBiometric) {
        try {
          final biometricData = await _biometricService.generateBiometricDataMap();
          deviceId = biometricData['device_id'];
          biometricHash = biometricData['biometric_hash'];
        } catch (e) {
          // Si falla la biometría, continuar sin ella
          _enableBiometric = false;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudo configurar la biometría. Registro sin autenticación biométrica.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
      
      // Registrar usuario en Supabase
      final result = await _authService.registerUser(
        name: fullName,
        email: _emailController.text.trim(),
        password: _passwordController.text,
        dni: _dniController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        enableBiometric: _enableBiometric,
        deviceId: deviceId,
        biometricHash: biometricHash,
      );

      if (result['success'] == true) {
        // Si se habilitó biometría, actualizar el estado en AuthProvider
        if (_enableBiometric && mounted) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          await authProvider.checkBiometricData();
          print('📱 RegisterScreen: Estado biométrico actualizado en AuthProvider');
        }
        
        // Mostrar mensaje de éxito
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Registro exitoso'),
              backgroundColor: Colors.green,
            ),
          );

          // Regresar a la pantalla de login
          Navigator.of(context).pop();
        }
      } else {
        // Mostrar mensaje de error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Error en el registro'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en el registro: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _addressController.dispose();
    _dniController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Usuario'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // Información sobre asignación de roles
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tu rol será asignado por un gerente después del registro',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombres',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) => (value?.isEmpty ?? true) ? 'Este campo es obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Apellidos',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) => (value?.isEmpty ?? true) ? 'Este campo es obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (value) => (value?.isEmpty ?? true) ? 'Este campo es obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dniController,
              decoration: const InputDecoration(
                labelText: 'DNI',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              validator: (value) => (value?.length ?? 0) < 8 ? 'El DNI debe tener 8 dígitos' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Celular',
                prefixText: '+51 ',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              validator: (value) => (value?.length ?? 0) < 9 ? 'El celular debe tener 9 dígitos' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Correo Electrónico',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Este campo es obligatorio';
                if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) return 'Ingresa un correo válido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: (value) => (value?.length ?? 0) < 6 ? 'La contraseña debe tener al menos 6 caracteres' : null,
            ),
            const SizedBox(height: 20),
            // Opción de autenticación biométrica
            if (_biometricAvailable)
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.fingerprint, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Autenticación Biométrica',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            'Habilita el acceso rápido con huella dactilar',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _enableBiometric,
                      onChanged: (value) {
                        setState(() {
                          _enableBiometric = value;
                        });
                      },
                      activeThumbColor: Colors.green.shade700,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Registrarse'),
            ),
          ],
        ),
      ),
    );
  }
}