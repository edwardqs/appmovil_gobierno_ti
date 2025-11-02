# 🧪 Guía Completa de Pruebas - Autenticación Biométrica Multi-Dispositivo

## 📋 Tabla de Contenidos
1. [Preparación del Entorno](#preparación-del-entorno)
2. [Casos de Prueba Críticos](#casos-de-prueba-críticos)
3. [Matriz de Escenarios](#matriz-de-escenarios)
4. [Comandos de Verificación](#comandos-de-verificación)

---

## 🔧 Preparación del Entorno

### 1. Ejecutar Scripts SQL
```bash
# En Supabase SQL Editor, ejecutar en orden:
1. supabase_users_table_update.sql
2. supabase_session_validation.sql
```

### 2. Verificar Configuración de Supabase
```dart
// lib/core/supabase_config.dart
// Verificar que las credenciales sean correctas
static const String supabaseUrl = 'https://ulcvogvadzjzkipbafll.supabase.co';
static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

### 3. Limpiar Estado de la Aplicación
```bash
# Limpiar caché de Flutter
flutter clean
flutter pub get

# Desinstalar app del dispositivo (opcional pero recomendado)
# Esto limpia todas las credenciales almacenadas localmente
```

---

## ✅ Casos de Prueba Críticos

### **CASO 1: Login Básico con Email/Contraseña**

#### Objetivo
Verificar que el login tradicional funciona correctamente y renueva credenciales biométricas si estaban habilitadas.

#### Pasos
1. Abrir la app en **Dispositivo A**
2. Iniciar sesión con:
   - Email: `test@example.com`
   - Contraseña: `password123`
3. Verificar que se accede al dashboard

#### Resultado Esperado
✅ Login exitoso
✅ Dashboard se muestra correctamente
✅ Perfil de usuario cargado con rol correcto

#### Logs Esperados
```
🔐 [LOGIN_EMAIL] Iniciando login con email...
✅ [LOGIN_EMAIL] Login exitoso, obteniendo perfil...
👤 [LOGIN_EMAIL] Perfil obtenido. Biometría habilitada: false
```

---

### **CASO 2: Habilitar Biometría por Primera Vez**

#### Objetivo
Verificar que se puede habilitar la biometría y que las credenciales se guardan correctamente.

#### Pasos
1. Con sesión activa en **Dispositivo A**
2. Ir a `Dashboard → Menú → Configurar Biometría`
3. Presionar "Habilitar Biometría"
4. Completar autenticación biométrica (huella/rostro)
5. Verificar mensaje de éxito

#### Resultado Esperado
✅ Autenticación biométrica solicitada
✅ Mensaje: "¡Acceso biométrico habilitado exitosamente!"
✅ Botón de huella visible en pantalla de login

#### Logs Esperados
```
🔐 [BIOMETRIC] Iniciando habilitación de biometría...
✅ [BIOMETRIC] Sesión válida (expira en X minutos)
💾 [BIOMETRIC] Credenciales guardadas en secure storage
📱 [BIOMETRIC] Device ID: 1234567890_user-uuid
✅ [BIOMETRIC] Estado biométrico y device_id actualizados en la base de datos
```

#### Verificación en Supabase
```sql
-- Ejecutar en Supabase SQL Editor
SELECT id, email, biometric_enabled, device_id, updated_at
FROM public.users
WHERE email = 'test@example.com';
```

**Resultado esperado:**
| biometric_enabled | device_id | 
|-------------------|-----------|
| true | 1234567890_user-uuid |

---

### **CASO 3: Login Biométrico en el Mismo Dispositivo**

#### Objetivo
Verificar que el login biométrico funciona correctamente en el dispositivo donde se habilitó.

#### Pasos
1. Cerrar sesión en **Dispositivo A**
2. En pantalla de login, presionar el botón de huella 👆
3. Completar autenticación biométrica

#### Resultado Esperado
✅ Autenticación biométrica solicitada
✅ Login exitoso sin pedir email/contraseña
✅ Dashboard se muestra correctamente

#### Logs Esperados
```
🔐 [LOGIN_BIOMETRIC] Iniciando login biométrico...
✅ [LOGIN_BIOMETRIC] Autenticación biométrica exitosa
📱 [LOGIN_BIOMETRIC] Credenciales encontradas, parseando...
🔄 [LOGIN_BIOMETRIC] Intentando refrescar sesión con refresh_token...
✅ [LOGIN_BIOMETRIC] Sesión refrescada exitosamente
✅ [LOGIN_BIOMETRIC] Perfil de usuario obtenido: test@example.com
```

---

### **CASO 4: Login Manual en Dispositivo B (Crítico)**

#### Objetivo
Verificar que al iniciar sesión en un segundo dispositivo, las credenciales del primero siguen funcionando.

#### Pasos
1. En **Dispositivo B** (nuevo dispositivo), iniciar sesión manualmente:
   - Email: `test@example.com`
   - Contraseña: `password123`
2. Verificar acceso al dashboard
3. **SIN CERRAR SESIÓN en Dispositivo B**, volver a **Dispositivo A**
4. Intentar login biométrico en **Dispositivo A**

#### Resultado Esperado en Dispositivo B
✅ Login exitoso
✅ Dashboard accesible
✅ Logs muestran renovación de credenciales (si biometría estaba habilitada)

#### Resultado Esperado en Dispositivo A
✅ Login biométrico funciona correctamente
✅ **NO se muestra error de "sesión expirada"**
✅ Ambos dispositivos pueden estar autenticados simultáneamente

#### Logs Esperados en Dispositivo A
```
🔐 [LOGIN_BIOMETRIC] Iniciando login biométrico...
✅ [LOGIN_BIOMETRIC] Autenticación biométrica exitosa
📱 [BIOMETRIC] Device ID: 1234567890_user-uuid (coincide)
✅ [LOGIN_BIOMETRIC] Sesión refrescada exitosamente
```

---

### **CASO 5: Habilitar Biometría en Dispositivo B**

#### Objetivo
Verificar que se puede habilitar biometría en un segundo dispositivo sin afectar al primero.

#### Pasos
1. En **Dispositivo B** (con sesión activa)
2. Ir a `Dashboard → Menú → Configurar Biometría`
3. Presionar "Habilitar Biometría"
4. Completar autenticación biométrica
5. Cerrar sesión
6. Probar login biométrico en **Dispositivo B**
7. Probar login biométrico en **Dispositivo A**

#### Resultado Esperado
✅ Biometría se habilita en **Dispositivo B**
✅ Login biométrico funciona en **Dispositivo B**
✅ Login biométrico sigue funcionando en **Dispositivo A**
✅ Cada dispositivo tiene su propio `device_id`

#### Verificación en Supabase
```sql
-- Ver auditoría de cambios biométricos
SELECT * FROM public.biometric_audit_log
WHERE user_id = (SELECT id FROM public.users WHERE email = 'test@example.com')
ORDER BY created_at DESC;
```

**Resultado esperado:**
| action | device_id | old_device_id |
|--------|-----------|---------------|
| device_changed | 0987654321_user-uuid | 1234567890_user-uuid |

---

### **CASO 6: Deshabilitar Biometría**

#### Objetivo
Verificar que al deshabilitar la biometría se limpian las credenciales correctamente.

#### Pasos
1. Con sesión activa en **Dispositivo A**
2. Ir a `Dashboard → Menú → Configurar Biometría`
3. Presionar "Deshabilitar Biometría"
4. Verificar mensaje de confirmación
5. Cerrar sesión
6. Intentar login biométrico (botón de huella NO debe estar visible o debe estar deshabilitado)

#### Resultado Esperado
✅ Mensaje: "Acceso biométrico deshabilitado"
✅ Botón de huella desaparece o se deshabilita
✅ Credenciales locales limpiadas

#### Verificación en Supabase
```sql
SELECT biometric_enabled, device_id FROM public.users
WHERE email = 'test@example.com';
```

**Resultado esperado:**
| biometric_enabled | device_id |
|-------------------|-----------|
| false | NULL |

---

### **CASO 7: Manejo de Sesión Expirada (Edge Case)**

#### Objetivo
Verificar que el sistema maneja correctamente un refresh_token expirado.

#### Pasos
1. Habilitar biometría en **Dispositivo A**
2. **Esperar 60 días** (o modificar manualmente el `expires_at` en la BD)
3. Intentar login biométrico

#### Resultado Esperado
❌ Error: "Credenciales biométricas expiradas. Inicia sesión manualmente."
✅ Credenciales locales limpiadas automáticamente
✅ Usuario puede iniciar sesión manualmente

#### Simulación Manual
```sql
-- Simular expiración de credenciales
UPDATE public.users
SET updated_at = NOW() - INTERVAL '61 days'
WHERE email = 'test@example.com';
```

---

### **CASO 8: Device ID Mismatch (Seguridad)**

#### Objetivo
Verificar que no se puede usar credenciales biométricas de otro dispositivo.

#### Pasos
1. Habilitar biometría en **Dispositivo A**
2. **Extraer credenciales** (solo con fines de prueba, NO hacer esto en producción):
   - Android: `/data/data/com.appbogiernoti.app_gobiernoti/shared_prefs/FlutterSecureStorage.xml`
   - iOS: Keychain Access
3. Copiar credenciales a **Dispositivo B**
4. Intentar login biométrico en **Dispositivo B**

#### Resultado Esperado
❌ Error: "Este dispositivo no coincide con el registrado. Inicia sesión manualmente."
✅ No se permite acceso con credenciales de otro dispositivo

---

## 📊 Matriz de Escenarios

| Escenario | Dispositivo A | Dispositivo B | Resultado Esperado |
|-----------|---------------|---------------|---------------------|
| Login manual | ✅ Activo | - | Acceso garantizado |
| Habilitar biometría | ✅ Habilitado | - | Credenciales guardadas |
| Login biométrico | ✅ Login exitoso | - | Acceso sin contraseña |
| Login manual en B | ✅ Sigue activo | ✅ Nuevo login | Ambos activos |
| Login biométrico A | ✅ Funciona | ✅ Activo manual | Ambos funcionan |
| Habilitar biometría B | ✅ Sigue funcionando | ✅ Biometría habilitada | Independientes |
| Deshabilitar en A | ❌ Biometría OFF | ✅ Sigue funcionando | Solo B tiene biometría |

---

## 🛠️ Comandos de Verificación

### Ver Estado de Sesiones Activas
```sql
-- Ver usuarios con biometría habilitada
SELECT 
    id,
    email,
    name,
    role,
    biometric_enabled,
    device_id,
    created_at,
    updated_at
FROM public.users
WHERE biometric_enabled = TRUE
ORDER BY updated_at DESC;
```

### Ver Auditoría de Cambios Biométricos
```sql
SELECT 
    bal.created_at,
    u.email,
    bal.action,
    bal.device_id,
    bal.old_device_id
FROM public.biometric_audit_log bal
JOIN public.users u ON u.id = bal.user_id
ORDER BY bal.created_at DESC
LIMIT 50;
```

### Ver Estadísticas de Uso Biométrico
```sql
SELECT * FROM public.get_biometric_stats();
```

### Limpiar Dispositivos Antiguos (Mantenimiento)
```sql
-- Deshabilitar biometría para usuarios inactivos por más de 60 días
SELECT * FROM public.cleanup_old_biometric_devices(60);
```

---

## 🐛 Troubleshooting

### Error: "Credenciales biométricas no encontradas"
**Causa**: Credenciales locales no existen o fueron limpiadas.
**Solución**: Iniciar sesión manualmente y volver a habilitar biometría.

### Error: "Este dispositivo no coincide con el registrado"
**Causa**: El `device_id` local no coincide con el guardado en la BD.
**Solución**: Deshabilitar y volver a habilitar biometría en este dispositivo.

### Error: "Sesión biométrica expirada"
**Causa**: El `refresh_token` guardado expiró.
**Solución**: Iniciar sesión manualmente para renovar credenciales.

### Botón de Huella no Aparece
**Verificar**:
1. `SharedPreferences` → `biometric_enabled` debe ser `true`
2. `FlutterSecureStorage` → Debe tener credenciales guardadas
3. Verificar logs de `checkBiometricStatus()`

---

## ✅ Checklist Final

Antes de considerar las pruebas completas, verificar:

- [ ] Login manual funciona en ambos dispositivos
- [ ] Habilitar biometría guarda `device_id` en BD
- [ ] Login biométrico funciona en el mismo dispositivo
- [ ] Login manual en dispositivo B no invalida credenciales de A
- [ ] Ambos dispositivos pueden tener biometría habilitada simultáneamente
- [ ] Deshabilitar biometría limpia credenciales locales y en BD
- [ ] Manejo correcto de errores (token expirado, device mismatch)
- [ ] Auditoría registra todos los cambios correctamente
- [ ] No hay logs de error en consola durante flujos normales

---

## 📝 Notas Adicionales

### Seguridad
- Las credenciales biométricas NUNCA salen del dispositivo
- El `device_id` es único por dispositivo y no se puede falsificar fácilmente
- El `refresh_token` se guarda encriptado en el Keychain/Keystore del dispositivo

### Performance
- El login biométrico es ~3x más rápido que el manual
- La renovación automática de credenciales evita re-autenticaciones innecesarias

### Mantenimiento
- Ejecutar `cleanup_old_biometric_devices(60)` mensualmente como tarea cron
- Monitorear tabla `biometric_audit_log` para detectar patrones anómalos

---

**Última actualización**: 2024-01-XX
**Versión del sistema**: 1.0.0