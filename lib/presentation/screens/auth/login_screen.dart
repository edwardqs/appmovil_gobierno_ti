import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_gobiernoti/data/services/biometric_service.dart';
import 'package:app_gobiernoti/presentation/screens/auth/register_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animations/fade_in_animation.dart';
import 'package:local_auth/local_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final BiometricService _biometricService = BiometricService();

  Future<void> _loginWithBiometrics() async {
    final List<BiometricType> availableBiometrics =
    await _biometricService.getAvailableBiometrics();

    if (kDebugMode) {
      print("Biométricos disponibles: $availableBiometrics");
    }

    if (availableBiometrics.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró un sensor biométrico compatible.')),
      );
      return;
    }

    String reason = 'Usa tu biometría para iniciar sesión';
    if (availableBiometrics.contains(BiometricType.face)) {
      reason = 'Usa tu rostro para iniciar sesión';
    } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
      reason = 'Usa tu huella para iniciar sesión';
    }

    try {
      final isAuthenticated = await _biometricService.authenticate(reason);

      if (isAuthenticated && mounted) {
        Provider.of<AuthProvider>(context, listen: false)
            .login('biometric@user.com', 'password');
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error durante la autenticación: $e");
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
                      // ▼▼▼ ÍCONO CAMBIADO AQUÍ ▼▼▼
                      IconButton(
                        onPressed: _loginWithBiometrics,
                        icon: const Icon(Icons.fingerprint, size: 30),
                        color: AppColors.primary,
                        tooltip: 'Iniciar con biometría',
                      ),
                      // ▲▲▲ FIN DEL CAMBIO ▲▲▲
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
                    child:
                    const Text('¿No tienes una cuenta? Regístrate aquí'),
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