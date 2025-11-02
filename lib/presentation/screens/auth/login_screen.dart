import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_gobiernoti/data/services/auth_service.dart';
import 'package:app_gobiernoti/presentation/screens/auth/register_screen.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animations/fade_in_animation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();


  Future<void> _loginWithBiometrics(AuthProvider authProvider) async {
    print('🔐 Iniciando login biométrico...');
    
    final hasBiometricData = authProvider.hasBiometricDataValue;
    print('🔐 ¿Tiene datos biométricos? $hasBiometricData');
    
    if (!hasBiometricData) {
      print('🔐 No hay datos biométricos configurados');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tienes configurada la autenticación biométrica'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    print('🔐 Intentando autenticación biométrica...');
    try {
      final user = await _authService.loginWithBiometrics();
      print('🔐 Resultado de autenticación: ${user != null ? "Exitoso" : "Falló"}');

      if (user != null && mounted) {
        // Actualizar el provider con el usuario autenticado
        authProvider.setCurrentUser(user);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inicio de sesión biométrico exitoso'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error en la autenticación biométrica'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error durante la autenticación biométrica: $e");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.login(
      _emailController.text,
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FadeInAnimation(
                  delay: 0.5,
                  child: Icon(
                    Icons.shield_outlined,
                    size: 80,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                FadeInAnimation(
                  delay: 0.7,
                  child: Text(
                    'GRC Mobile',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 8),
                FadeInAnimation(
                  delay: 0.9,
                  child: Text(
                    'Evaluación de Riesgos de TI',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 40),
                FadeInAnimation(
                  delay: 1.1,
                  child: TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => (value?.isEmpty ?? true)
                        ? 'Por favor ingrese un email'
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                FadeInAnimation(
                  delay: 1.3,
                  child: TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock_outline)),
                    obscureText: true,
                    validator: (value) => (value?.isEmpty ?? true)
                        ? 'Por favor ingrese una contraseña'
                        : null,
                  ),
                ),
                Consumer<AuthProvider>(
                  builder: (context, auth, child) {
                    if (auth.errorMessage != null && !auth.isLoading) {
                      return FadeInAnimation(
                        delay: 1.4,
                        child: Padding(
                          padding:
                          const EdgeInsets.only(top: 20.0, bottom: 0),
                          child: Text(
                            auth.errorMessage!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return const SizedBox(height: 0);
                  },
                ),
                const SizedBox(height: 30),
                FadeInAnimation(
                  delay: 1.5,
                  child: Row(
                    children: [
                      Expanded(
                        child: Consumer<AuthProvider>(
                            builder: (context, auth, child) {
                              return ElevatedButton(
                                onPressed: auth.isLoading ? null : _login,
                                child: auth.isLoading
                                    ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 3))
                                    : const Text('Iniciar Sesión'),
                              );
                            }),
                      ),
                      const SizedBox(width: 16),
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          return IconButton(
                            onPressed: authProvider.hasBiometricDataValue
                                ? () => _loginWithBiometrics(authProvider)
                                : null,
                            icon: Icon(
                              Icons.fingerprint,
                              size: 30,
                              color: authProvider.hasBiometricDataValue
                                  ? AppColors.primary
                                  : Colors.grey,
                            ),
                            tooltip: authProvider.hasBiometricDataValue
                                ? 'Iniciar con biometría'
                                : 'Biometría no configurada',
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FadeInAnimation(
                  delay: 1.7,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ));
                    },
                    child: const Text('¿No tienes cuenta? Regístrate aquí'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}