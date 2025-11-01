
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:app_gobiernoti/data/models/user_model.dart';
import 'package:app_gobiernoti/data/services/auth_service.dart';
import 'package:app_gobiernoti/presentation/providers/auth_provider.dart';

// Genera un archivo mock para AuthService.
@GenerateMocks([AuthService])
import 'auth_provider_test.mocks.dart';

// Una clase falsa de UserModel para usar en las pruebas.
class FakeUserModel extends Fake implements UserModel {
  @override
  final String id;
  @override
  final String name;
  @override
  final String email;

  FakeUserModel({this.id = '1', this.name = 'Test User', this.email = 'test@test.com'});
}

void main() {
  late AuthProvider authProvider;
  late MockAuthService mockAuthService;
  late UserModel testUser;

  setUp(() {
    mockAuthService = MockAuthService();
    authProvider = AuthProvider(mockAuthService);
    testUser = FakeUserModel();
  });

  group('AuthProvider', () {
    test('Initial state should be correct', () {
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.currentUser, isNull);
      expect(authProvider.errorMessage, isNull);
    });

    test('login success should return true and update state', () async {
      // Arrange
      when(mockAuthService.login(any, any)).thenAnswer((_) async => testUser);

      // Act
      final result = await authProvider.login('test@test.com', 'password');

      // Assert
      expect(result, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.currentUser, testUser);
      expect(authProvider.errorMessage, isNull);
      verify(mockAuthService.login('test@test.com', 'password')).called(1);
    });

    test('login failure should return false and update state', () async {
      // Arrange
      when(mockAuthService.login(any, any)).thenAnswer((_) async => null);

      // Act
      final result = await authProvider.login('wrong@test.com', 'wrongpassword');

      // Assert
      expect(result, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.currentUser, isNull);
      expect(authProvider.errorMessage, isNotNull);
      verify(mockAuthService.login('wrong@test.com', 'wrongpassword')).called(1);
    });

    test('logout should clear user and notify listeners', () async {
      // Arrange: Primero, simula un estado de "logueado".
      when(mockAuthService.login(any, any)).thenAnswer((_) async => testUser);
      await authProvider.login('test@test.com', 'password');
      expect(authProvider.isAuthenticated, isTrue); // Pre-condición

      // Configura el mock para logout.
      when(mockAuthService.logout()).thenAnswer((_) async {});

      // Act
      await authProvider.logout();

      // Assert
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.currentUser, isNull);
      verify(mockAuthService.logout()).called(1);
    });
  });
}
