class AuditService {
  final List<String> _auditLog = [];

  List<String> get auditLog => _auditLog;

  void logLoginAttempt(String email, {required bool success, String? error}) {
    final timestamp = DateTime.now().toIso8601String();
    final status = success ? 'SUCCESS' : 'FAILURE';
    final logMessage = '[$timestamp] - Login attempt for $email: $status';

    if (error != null) {
      _auditLog.add('$logMessage - Error: $error');
    } else {
      _auditLog.add(logMessage);
    }

    // En una aplicación real, aquí enviarías el log a un servidor o lo guardarías
    // en un almacenamiento persistente.
    print(logMessage);
  }
}