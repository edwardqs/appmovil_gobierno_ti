import 'package:flutter/material.dart';
import '../../../core/supabase_config.dart';

class SupabaseTestScreen extends StatefulWidget {
  const SupabaseTestScreen({super.key});

  @override
  State<SupabaseTestScreen> createState() => _SupabaseTestScreenState();
}

class _SupabaseTestScreenState extends State<SupabaseTestScreen> {
  String _connectionStatus = 'No probado';
  String _registerResult = 'No probado';
  String _loginResult = 'No probado';
  bool _isLoading = false;

  // Controladores para el formulario de prueba
  final _emailController = TextEditingController(text: 'test@ejemplo.com');
  final _passwordController = TextEditingController(text: 'password123');
  final _nameController = TextEditingController(text: 'Usuario Prueba');
  final _dniController = TextEditingController(text: '12345678');
  final _phoneController = TextEditingController(text: '+51987654321');
  final _addressController = TextEditingController(text: 'Dirección de prueba');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _dniController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _connectionStatus = 'Probando conexión...';
    });

    try {
      final result = await SupabaseConfig.testConnection();
      setState(() {
        _connectionStatus = result['success'] 
            ? '✅ ${result['message']}'
            : '❌ ${result['message']}';
      });
    } catch (e) {
      setState(() {
        _connectionStatus = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testRegisterFunction() async {
    setState(() {
      _isLoading = true;
      _registerResult = 'Probando registro...';
    });

    try {
      final result = await SupabaseConfig.client.rpc(
        'register_user',
        params: {
          'p_email': _emailController.text,
          'p_password': _passwordController.text,
          'p_name': _nameController.text,
          'p_dni': _dniController.text,
          'p_phone': _phoneController.text,
          'p_address': _addressController.text,
        },
      );

      setState(() {
        if (result['success'] == true) {
          _registerResult = '✅ ${result['message']}\n'
              'Usuario ID: ${result['user_id']}\n'
              'Rol: ${result['role']}';
        } else {
          _registerResult = '❌ ${result['message']}';
        }
      });
    } catch (e) {
      setState(() {
        _registerResult = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testLoginFunction() async {
    setState(() {
      _isLoading = true;
      _loginResult = 'Probando login...';
    });

    try {
      print('🔐 Intentando login con email: ${_emailController.text}');
      
      // Paso 1: Autenticación con Supabase Auth
      final authResponse = await SupabaseConfig.client.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      print('✅ Autenticación exitosa. User ID: ${authResponse.user?.id}');

      // Paso 2: Obtener perfil del usuario
      final profileResponse = await SupabaseConfig.client.rpc(
        'get_user_profile',
        params: {
          'p_user_id': authResponse.user!.id,
        },
      );

      print('📋 Respuesta del perfil: $profileResponse');

      setState(() {
        if (profileResponse['success'] == true) {
          final userData = profileResponse['data'];
          _loginResult = '✅ Login exitoso!\n'
              'Email: ${userData['email']}\n'
              'Nombre: ${userData['name']}\n'
              'DNI: ${userData['dni']}\n'
              'Rol: ${userData['role']}\n'
              'Biométrico habilitado: ${userData['biometric_enabled']}';
        } else {
          _loginResult = '❌ Error en perfil: ${profileResponse['message']}';
        }
      });

      // Cerrar sesión después de la prueba
      await SupabaseConfig.client.auth.signOut();
      print('🚪 Sesión cerrada después de la prueba');

    } catch (e) {
      print('❌ Error en login: $e');
      setState(() {
        _loginResult = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkTables() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Verificar tabla users
      await SupabaseConfig.client
          .from('users')
          .select('count')
          .limit(1);
      
      // Verificar tabla biometric_tokens
      await SupabaseConfig.client
          .from('biometric_tokens')
          .select('count')
          .limit(1);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Estado de las Tablas'),
          content: const Text(
            '✅ Tabla users: Accesible\n'
            '✅ Tabla biometric_tokens: Accesible\n'
            '✅ Todas las tablas están funcionando correctamente'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error en Tablas'),
          content: Text('❌ Error al acceder a las tablas: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pruebas de Supabase'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Test de Conexión
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. Prueba de Conexión',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_connectionStatus),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _testConnection,
                        child: const Text('Probar Conexión'),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Test de Tablas
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2. Verificar Tablas',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Verifica que las tablas users y biometric_tokens existan'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _checkTables,
                        child: const Text('Verificar Tablas'),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Test de Registro
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '3. Prueba de Registro',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      // Formulario de prueba
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _dniController,
                        decoration: const InputDecoration(
                          labelText: 'DNI',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Text(
                        'Resultado:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(_registerResult),
                      ),
                      const SizedBox(height: 16),
                      
                      ElevatedButton(
                        onPressed: _isLoading ? null : _testRegisterFunction,
                        child: const Text('Probar Registro'),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Test de Login
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '4. Prueba de Login',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Usa las mismas credenciales del registro para probar el login.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      
                      Text(
                        'Resultado:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(_loginResult),
                      ),
                      const SizedBox(height: 16),
                      
                      ElevatedButton(
                        onPressed: _isLoading ? null : _testLoginFunction,
                        child: const Text('Probar Login'),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}