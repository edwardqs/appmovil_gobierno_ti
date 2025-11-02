import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://ulcvogvadzjzkipbafll.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVsY3ZvZ3ZhZHpqemtpcGJhZmxsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwMTE2ODEsImV4cCI6MjA3NzU4NzY4MX0.n7dZzYq44I6w-cU0J3c7L4EhdFJWPk7k5w0ZZGIyvCA';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true, // Solo para desarrollo
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;

  /// Verifica el estado de la sesión actual
  static Map<String, dynamic> getSessionStatus() {
    try {
      final session = auth.currentSession;
      final user = auth.currentUser;
      
      return {
        'hasSession': session != null,
        'isAuthenticated': user != null,
        'userId': user?.id,
        'userEmail': user?.email,
        'sessionExpiry': session?.expiresAt,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'hasSession': false,
        'isAuthenticated': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}