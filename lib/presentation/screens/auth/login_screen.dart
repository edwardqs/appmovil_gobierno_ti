// Eliminamos 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_gobiernoti/presentation/screens/auth/register_screen.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Limpiar errores al entrar a la pantalla
    // y comprobar el estado biométrico
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.clearError();
      authProvider.checkBiometricStatus(); // Revisa si el botón debe mostrarse
    });
  }

  Future<void> _handleLogin(AuthProvider authProvider) async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    // Llama al provider
    await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    // Si hay un error después del login, muéstralo
    if (authProvider.status == AuthStatus.error && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Error desconocido'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleBiometricLogin(AuthProvider authProvider) async {
    await authProvider.loginWithBiometrics();

    if (authProvider.status == AuthStatus.error && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Error de biometría'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                const Icon(
                  Icons.shield_outlined,
                  size: 80,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'GRC Mobile',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Evaluación de Riesgos de TI',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => (value?.isEmpty ?? true)
                      ? 'Por favor ingrese un email'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) => (value?.isEmpty ?? true)
                      ? 'Por favor ingrese una contraseña'
                      : null,
                ),
                Consumer<AuthProvider>(
                  builder: (context, auth, child) {
                    // Lógica de error actualizada
                    if (auth.status == AuthStatus.error &&
                        auth.errorMessage != null) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 20.0, bottom: 0),
                        child: Text(
                          auth.errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return const SizedBox(height: 0);
                  },
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: Consumer<AuthProvider>(
                        builder: (context, auth, child) {
                          final isLoading = auth.status == AuthStatus.loading;
                          return ElevatedButton(
                            // Lógica de botón actualizada
                            onPressed: isLoading
                                ? null
                                : () => _handleLogin(auth),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Text('Iniciar Sesión'),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, child) {
                        final isLoading = authProvider.status == AuthStatus.loading;
                        final canUseBiometric = authProvider.hasBiometricData && !isLoading;
                        
                        return IconButton(
                          onPressed: canUseBiometric
                              ? () => _handleBiometricLogin(authProvider)
                              : null,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.fingerprint,
                                  size: 30,
                                  color: authProvider.hasBiometricData
                                      ? AppColors.primary
                                      : Colors.grey,
                                ),
                          tooltip: isLoading
                              ? 'Autenticando...'
                              : authProvider.hasBiometricData
                                  ? 'Iniciar con biometría'
                                  : 'Biometría no configurada',
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    // Usar la navegación a RegisterScreen (o GoRouter)
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text('¿No tienes cuenta? Regístrate aquí'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
