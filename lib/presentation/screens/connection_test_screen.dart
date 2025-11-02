import 'package:flutter/material.dart';
import '../../core/supabase_config.dart';

class ConnectionTestScreen extends StatefulWidget {
  const ConnectionTestScreen({super.key});

  @override
  State<ConnectionTestScreen> createState() => _ConnectionTestScreenState();
}

class _ConnectionTestScreenState extends State<ConnectionTestScreen> {
  Map<String, dynamic>? _connectionResult;
  Map<String, dynamic>? _sessionStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getSessionStatus();
  }

  void _getSessionStatus() {
    setState(() {
      _sessionStatus = SupabaseConfig.getSessionStatus();
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _connectionResult = null;
    });

    try {
      final result = await SupabaseConfig.testConnection();
      setState(() {
        _connectionResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _connectionResult = {
          'success': false,
          'message': 'Error inesperado: ${e.toString()}',
          'timestamp': DateTime.now().toIso8601String(),
        };
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prueba de Conexión Supabase'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Información de configuración
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuración de Supabase',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('URL: ${SupabaseConfig.supabaseUrl}'),
                    const SizedBox(height: 4),
                    Text('Clave: ${SupabaseConfig.supabaseAnonKey.substring(0, 20)}...'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Estado de la sesión
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado de la Sesión',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (_sessionStatus != null) ...[
                      _buildStatusRow('Tiene sesión', _sessionStatus!['hasSession']),
                      _buildStatusRow('Autenticado', _sessionStatus!['isAuthenticated']),
                      if (_sessionStatus!['userId'] != null)
                        Text('ID Usuario: ${_sessionStatus!['userId']}'),
                      if (_sessionStatus!['userEmail'] != null)
                        Text('Email: ${_sessionStatus!['userEmail']}'),
                      if (_sessionStatus!['error'] != null)
                        Text('Error: ${_sessionStatus!['error']}', 
                             style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _getSessionStatus,
                      child: const Text('Actualizar Estado'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Botón de prueba
            ElevatedButton(
              onPressed: _isLoading ? null : _testConnection,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Probando conexión...'),
                      ],
                    )
                  : const Text('Probar Conexión'),
            ),
            const SizedBox(height: 16),

            // Resultado de la prueba
            if (_connectionResult != null)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _connectionResult!['success'] == true
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _connectionResult!['success'] == true
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Resultado de la Prueba',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Estado: ${_connectionResult!['success'] == true ? 'ÉXITO' : 'ERROR'}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _connectionResult!['success'] == true
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('Mensaje: ${_connectionResult!['message']}'),
                                const SizedBox(height: 8),
                                Text('Timestamp: ${_connectionResult!['timestamp']}'),
                                if (_connectionResult!['url'] != null) ...[
                                  const SizedBox(height: 8),
                                  Text('URL: ${_connectionResult!['url']}'),
                                ],
                                if (_connectionResult!['error'] != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Error detallado: ${_connectionResult!['error']}',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: '),
          Icon(
            value == true ? Icons.check_circle : Icons.cancel,
            color: value == true ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            value == true ? 'Sí' : 'No',
            style: TextStyle(
              color: value == true ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}