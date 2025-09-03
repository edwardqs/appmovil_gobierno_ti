import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animations/fade_in_animation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'ciso@company.com');
  final _passwordController = TextEditingController(text: 'password');
  final _formKey = GlobalKey<FormState>();

  Future<void> _login() async {
    // Ocultar el teclado si está abierto
    FocusScope.of(context).unfocus(); 

    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // El resultado del login ahora se maneja por el estado de errorMessage en AuthProvider
    await authProvider.login(
      _emailController.text,
      _passwordController.text,
    );
    
    // La navegación basada en isAuthenticated la manejará el widget raíz (ej: main.dart)
    // o un listener específico en LoginScreen si se quisiera mantener aquí.
  }

  @override
  Widget build(BuildContext context) {
    // Usamos Consumer para reconstruir solo las partes necesarias cuando AuthProvider cambia.
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
                    decoration:
                    const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
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
                        labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline)),
                    obscureText: true,
                    validator: (value) => (value?.isEmpty ?? true)
                        ? 'Por favor ingrese una contraseña'
                        : null,
                  ),
                ),
                // Widget para mostrar el mensaje de error
                Consumer<AuthProvider>(
                  builder: (context, auth, child) {
                    if (auth.errorMessage != null && !auth.isLoading) {
                      return FadeInAnimation(
                        delay: 1.4, // Ajusta si es necesario
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20.0, bottom: 0), // Ajusta el padding
                          child: Text(
                            auth.errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return const SizedBox(height: 0); // No ocupa espacio si no hay error
                  },
                ),
                const SizedBox(height: 30),
                FadeInAnimation(
                  delay: 1.5,
                  child: SizedBox(
                    width: double.infinity,
                    child: Consumer<AuthProvider>(
                       builder: (context, auth, child) {
                        return ElevatedButton(
                          onPressed: auth.isLoading ? null : _login,
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 20, 
                                  height: 20, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                                )
                              : const Text('Iniciar Sesión'),
                        );
                       }
                    ),
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
