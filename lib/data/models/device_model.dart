// lib/data/models/device_model.dart

/// Modelo que representa un dispositivo registrado para un usuario
class DeviceModel {
  final String id;
  final String userId;
  final String deviceId;
  final String? deviceName;
  final String? deviceModel;
  final String? osVersion;
  final bool biometricEnabled;
  final DateTime lastUsedAt;
  final DateTime registeredAt;
  final bool isActive;

  DeviceModel({
    required this.id,
    required this.userId,
    required this.deviceId,
    this.deviceName,
    this.deviceModel,
    this.osVersion,
    required this.biometricEnabled,
    required this.lastUsedAt,
    required this.registeredAt,
    required this.isActive,
  });

  /// Crea una instancia desde JSON (respuesta de Supabase)
  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      deviceId: json['device_id'] as String,
      deviceName: json['device_name'] as String?,
      deviceModel: json['device_model'] as String?,
      osVersion: json['os_version'] as String?,
      biometricEnabled: json['biometric_enabled'] as bool? ?? false,
      lastUsedAt: DateTime.parse(json['last_used_at'] as String),
      registeredAt: DateTime.parse(json['registered_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// Convierte a JSON para enviar a Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'device_id': deviceId,
      'device_name': deviceName,
      'device_model': deviceModel,
      'os_version': osVersion,
      'biometric_enabled': biometricEnabled,
      'last_used_at': lastUsedAt.toIso8601String(),
      'registered_at': registeredAt.toIso8601String(),
      'is_active': isActive,
    };
  }

  /// Crea una copia del modelo con cambios opcionales
  DeviceModel copyWith({
    String? id,
    String? userId,
    String? deviceId,
    String? deviceName,
    String? deviceModel,
    String? osVersion,
    bool? biometricEnabled,
    DateTime? lastUsedAt,
    DateTime? registeredAt,
    bool? isActive,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceModel: deviceModel ?? this.deviceModel,
      osVersion: osVersion ?? this.osVersion,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      registeredAt: registeredAt ?? this.registeredAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Obtiene un nombre amigable del dispositivo
  String get displayName {
    if (deviceName != null && deviceName!.isNotEmpty) {
      return deviceName!;
    }
    if (deviceModel != null && deviceModel!.isNotEmpty) {
      return deviceModel!;
    }
    return 'Dispositivo ${deviceId.substring(0, 8)}...';
  }

  /// Obtiene una descripción completa del dispositivo
  String get fullDescription {
    final parts = <String>[];

    if (deviceName != null && deviceName!.isNotEmpty) {
      parts.add(deviceName!);
    }

    if (deviceModel != null && deviceModel!.isNotEmpty) {
      parts.add(deviceModel!);
    }

    if (osVersion != null && osVersion!.isNotEmpty) {
      parts.add(osVersion!);
    }

    if (parts.isEmpty) {
      return 'Dispositivo ${deviceId.substring(0, 8)}...';
    }

    return parts.join(' • ');
  }

  /// Verifica si este es el dispositivo actual
  bool isCurrentDevice(String currentDeviceId) {
    return deviceId == currentDeviceId;
  }

  /// Calcula el tiempo desde el último uso
  String get timeSinceLastUse {
    final difference = DateTime.now().difference(lastUsedAt);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inHours < 1) {
      return 'Hace ${difference.inMinutes} minutos';
    } else if (difference.inDays < 1) {
      return 'Hace ${difference.inHours} horas';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Hace $weeks ${weeks == 1 ? 'semana' : 'semanas'}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Hace $months ${months == 1 ? 'mes' : 'meses'}';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Hace $years ${years == 1 ? 'año' : 'años'}';
    }
  }

  @override
  String toString() {
    return 'DeviceModel(id: $id, deviceId: $deviceId, name: $deviceName, '
        'biometricEnabled: $biometricEnabled, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DeviceModel &&
        other.id == id &&
        other.deviceId == deviceId &&
        other.userId == userId;
  }

  @override
  int get hashCode => id.hashCode ^ deviceId.hashCode ^ userId.hashCode;
}
