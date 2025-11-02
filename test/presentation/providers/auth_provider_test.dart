
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:app_gobiernoti/data/models/user_model.dart';
import 'package:app_gobiernoti/data/services/auth_service.dart';
import 'package:app_gobiernoti/presentation/providers/auth_provider.dart';
import 'package:get_it/get_it.dart';

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
  @override
  final UserRole? role;
  @override
  final String? dni;
  @override
  final String? phone;
  @override
  final String? address;
  @override
  final bool biometricEnabled;
  @override
  final String? biometricToken;
  @override
  final String? deviceId;

  FakeUserModel({
    this.id = '1', 
    this.name = 'Test User', 
    this.email = 'test@test.com',
    this.role = UserRole.auditorJunior,
    this.dni = '12345678',
    this.phone,
    this.address,
    this.biometricEnabled = false,
    this.biometricToken,
    this.deviceId,
  });

  @override
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    bool? biometricEnabled,
    String? biometricToken,
    String? deviceId,
    String? dni,
    String? phone,
    String? address,
  }) {
    return FakeUserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      dni: dni ?? this.dni,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricToken: biometricToken ?? this.biometricToken,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}

void main() {
  late AuthProvider authProvider;
  late MockAuthService mockAuthService;
  late UserModel testUser;

  setUp(() {
    // Setup GetIt for dependency injection
    final getIt = GetIt.instance;
    getIt.reset();
    
    mockAuthService = MockAuthService();
    getIt.registerSingleton<AuthService>(mockAuthService);
    
    testUser = FakeUserModel();
    
    // Mock the checkBiometricStatus method
    when(mockAuthService.checkBiometricStatus()).thenAnswer((_) async => false);
    
    authProvider = AuthProvider();
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  group('AuthProvider', () {
    test('Initial state should be correct', () async {
      // Wait for initialization to complete
      await Future.delayed(Duration(milliseconds: 100));
      
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.currentUser, isNull);
      expect(authProvider.errorMessage, isNull);
      expect(authProvider.hasBiometricData, isFalse);
    });

    test('login success should update state correctly', () async {
      // Arrange
      when(mockAuthService.loginWithEmail(any, any)).thenAnswer((_) async => testUser);

      // Act
      await authProvider.login('test@test.com', 'password');

      // Assert
      expect(authProvider.status, AuthStatus.authenticated);
      expect(authProvider.currentUser?.id, testUser.id);
      expect(authProvider.currentUser?.email, testUser.email);
      expect(authProvider.errorMessage, isNull);
      verify(mockAuthService.loginWithEmail('test@test.com', 'password')).called(1);
    });

    test('login failure should update state with error', () async {
      // Arrange
      when(mockAuthService.loginWithEmail(any, any)).thenThrow(Exception('Invalid credentials'));

      // Act
      await authProvider.login('wrong@test.com', 'wrongpassword');

      // Assert
      expect(authProvider.status, AuthStatus.error);
      expect(authProvider.currentUser, isNull);
      expect(authProvider.errorMessage, 'Invalid credentials');
      verify(mockAuthService.loginWithEmail('wrong@test.com', 'wrongpassword')).called(1);
    });

    test('logout should clear user and update state', () async {
      // Arrange: First simulate a logged in state
      when(mockAuthService.loginWithEmail(any, any)).thenAnswer((_) async => testUser);
      await authProvider.login('test@test.com', 'password');
      expect(authProvider.status, AuthStatus.authenticated); // Pre-condition

      // Configure mock for logout
      when(mockAuthService.signOut()).thenAnswer((_) async {});

      // Act
      await authProvider.logout();

      // Assert
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.currentUser, isNull);
      verify(mockAuthService.signOut()).called(1);
    });

    test('register should work correctly', () async {
      // Arrange
      when(mockAuthService.registerUser(
        email: anyNamed('email'),
        password: anyNamed('password'),
        name: anyNamed('name'),
        role: anyNamed('role'),
        dni: anyNamed('dni'),
        phone: anyNamed('phone'),
        address: anyNamed('address'),
      )).thenAnswer((_) async => testUser);

      // Act
      final result = await authProvider.register(
        email: 'test@test.com',
        password: 'password',
        name: 'Test User',
        dni: '12345678',
      );

      // Assert
      expect(result, isTrue);
      expect(authProvider.status, AuthStatus.unauthenticated);
      verify(mockAuthService.registerUser(
        email: 'test@test.com',
        password: 'password',
        name: 'Test User',
        role: 'auditor_junior',
        dni: '12345678',
        phone: null,
        address: null,
      )).called(1);
    });

    test('clearError should clear error message and update status', () async {
      // Arrange: Set an error state
      when(mockAuthService.loginWithEmail(any, any)).thenThrow(Exception('Test error'));
      await authProvider.login('test@test.com', 'password');
      expect(authProvider.status, AuthStatus.error);
      expect(authProvider.errorMessage, 'Test error');

      // Act
      authProvider.clearError();

      // Assert
      expect(authProvider.errorMessage, isNull);
      expect(authProvider.status, AuthStatus.unauthenticated);
    });
  });
}
