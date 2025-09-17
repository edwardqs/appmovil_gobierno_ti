class AuthService {
  // Esto simula una llamada a tu API backend.
  // En el futuro, aquí usarás el paquete http para llamar a tu API FastAPI.
  Future<bool> login(String email, String password) async {
    // Simulación: Acepta credenciales específicas para la demo.
    // En una app real, aquí se validaría un token de una API.
    final bool isValidEmail = RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email);
    if (isValidEmail && password.isNotEmpty) {
      // Simula un retardo de red para dar una sensación más realista.
      await Future.delayed(const Duration(milliseconds: 1500));
      return true; // Login exitoso
    }
    await Future.delayed(const Duration(milliseconds: 800));
    return false; // Login fallido
  }

  Future<void> logout() async {
    // En una app real, aquí se limpiaría el token de autenticación.
    await Future.delayed(const Duration(milliseconds: 500));
  }
}