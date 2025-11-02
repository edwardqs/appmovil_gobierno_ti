# Guía de Pruebas: Flujo de Biometría Corregido

## ✅ Problemas Resueltos

### 1. Botón biométrico en gris después de logout
**SOLUCIÓN:** Login con email/password ahora guarda tokens VÁLIDOS de la sesión activa

### 2. Error "Auth session missing!" al login biométrico
**SOLUCIÓN:** Los tokens guardados son de la sesión activa, no tokens viejos invalidados

### 3. Deshabilitar biometría no actualiza BD
**SOLUCIÓN:** Ahora desactiva correctamente en `user_devices` y actualiza `users.biometric_enabled`

---

## 🔄 Flujo Correcto Implementado

```
1. HABILITAR BIOMETRÍA (primera vez)
   → Login con email/password
   → Dashboard → Menú → Configurar Biometría → Habilitar
   → Guarda: refresh_token, access_token, email, device_id
   → Registra dispositivo en user_devices
   → Actualiza users.biometric_enabled = true

2. LOGOUT
   → Supabase invalida los tokens en el servidor (normal)
   → Credenciales locales PERSISTEN (no se borran)

3. LOGIN BIOMÉTRICO (falla porque tokens invalidados)
   → Error: "Auth session missing!"
   → Se limpian credenciales locales automáticamente

4. LOGIN CON EMAIL/PASSWORD (sincronización automática)
   → Si users.biometric_enabled = true
   → Guarda NUEVOS tokens de la sesión activa
   → Estos tokens SÍ son válidos
   → Registra/actualiza dispositivo en user_devices

5. LOGOUT NUEVAMENTE
   → Tokens se invalidan en servidor
   → Credenciales locales persisten

6. LOGIN BIOMÉTRICO (ahora funciona)
   → Usa tokens guardados en paso 4 (VÁLIDOS)
   → refreshSession() funciona correctamente
   → Login exitoso ✅

7. CICLO SE REPITE
   → Cada login con email refresca los tokens
   → Login biométrico siempre usa tokens del último login email
```

---

## 🧪 Pasos de Prueba Completos

### Preparación

```bash
# 1. Actualizar código
git pull

# 2. Limpiar y recompilar
flutter clean
flutter pub get
flutter run
```

---

### Prueba 1: Usuario Nuevo - Habilitar Biometría

**Paso 1:** Registrarse
```
Pantalla: Registro
Email: test@ejemplo.com
Password: test123
... (otros campos)
→ Debe registrarse exitosamente
```

**Paso 2:** Login inicial
```
Pantalla: Login
Email: test@ejemplo.com
Password: test123
→ Entra al Dashboard
```

**Paso 3:** Habilitar biometría
```
Dashboard → Menú → Configurar Biometría
Click "Habilitar Biometría"
Autenticar con huella
→ Mensaje: "Biometría habilitada exitosamente" ✅
```

**Logs esperados:**
```
✅ [BIOMETRIC] Autenticación biométrica exitosa
📱 [BIOMETRIC] Device ID: ...
💾 [BIOMETRIC] Credenciales guardadas en almacenamiento seguro
✅ [DEVICE_SERVICE] Dispositivo registrado: tu_modelo
✅ [BIOMETRIC] Flag biometric_enabled actualizado en users
```

**Paso 4:** Logout
```
Dashboard → Menú → Cerrar Sesión
→ Vuelve a pantalla de Login
```

**Paso 5:** Verificar botón biométrico
```
Pantalla: Login
Botón de huella debe estar: ❌ GRIS (tokens invalidados por logout)
```

**Paso 6:** Login biométrico (falla esperado)
```
Click en botón de huella
→ Error: "Error en autenticación biométrica" ❌
→ Esto es NORMAL, los tokens se invalidaron
```

**Paso 7:** Login con email (sincronización)
```
Pantalla: Login
Email: test@ejemplo.com
Password: test123
→ Entra al Dashboard
```

**Logs esperados:**
```
👤 [LOGIN_EMAIL] Perfil obtenido. Biometría habilitada: true
🔄 [LOGIN_EMAIL] Usuario tiene biometría habilitada, guardando tokens de sesión activa...
✅ [LOGIN_EMAIL] Credenciales biométricas guardadas (tokens VÁLIDOS de sesión activa)
```

**Paso 8:** Logout nuevamente
```
Dashboard → Menú → Cerrar Sesión
```

**Paso 9:** Verificar botón biométrico
```
Pantalla: Login
Botón de huella debe estar: ✅ AZUL (credenciales sincronizadas)
```

**Paso 10:** Login biométrico (ahora funciona)
```
Click en botón de huella
Autenticar con huella
→ Entra al Dashboard ✅
```

**Logs esperados:**
```
✅ [LOGIN_BIOMETRIC] Autenticación biométrica exitosa
📱 [LOGIN_BIOMETRIC] Credenciales encontradas para: test@ejemplo.com
✅ [LOGIN_BIOMETRIC] Sesión refrescada exitosamente
✅ [LOGIN_BIOMETRIC] Dispositivo verificado en user_devices
✅ [LOGIN_BIOMETRIC] Login biométrico completado
```

---

### Prueba 2: Deshabilitar Biometría

**Paso 1:** Estar logueado con biometría habilitada

**Paso 2:** Ir a configuración
```
Dashboard → Menú → Configurar Biometría
Estado actual: "Biometría Habilitada"
```

**Paso 3:** Deshabilitar
```
Click en "Deshabilitar Biometría"
→ Mensaje: "Biometría deshabilitada en este dispositivo" ✅
```

**Logs esperados:**
```
🔐 [BIOMETRIC_DISABLE] Deshabilitando biometría en este dispositivo...
✅ [BIOMETRIC_DISABLE] Dispositivo desactivado en user_devices
✅ [BIOMETRIC_DISABLE] Credenciales locales limpiadas
📱 [BIOMETRIC_DISABLE] Dispositivos activos restantes: 0
✅ [BIOMETRIC_DISABLE] Flag biometric_enabled=false en users
```

**Paso 4:** Verificar en BD (opcional)
```sql
SELECT id, email, biometric_enabled, device_id
FROM users
WHERE email = 'test@ejemplo.com';
```
Resultado esperado:
- `biometric_enabled = false` ✅
- `device_id = null` (puede ser null o tener valor, no importa)

```sql
SELECT * FROM user_devices
WHERE user_id = (SELECT id FROM users WHERE email = 'test@ejemplo.com');
```
Resultado esperado:
- `is_active = false` ✅
- `biometric_enabled = false` ✅

**Paso 5:** Logout y verificar botón
```
Dashboard → Logout
Botón de huella: ❌ GRIS (biometría deshabilitada)
```

---

### Prueba 3: Usuario Existente con Biometría en BD

**Contexto:** Usuario que ya tiene `biometric_enabled = true` en BD

**Paso 1:** Verificar en BD
```sql
SELECT id, email, biometric_enabled
FROM users
WHERE email = 'usuario@ejemplo.com';
```
Debe tener: `biometric_enabled = true`

**Paso 2:** Flutter run (app desde cero)
```
Pantalla: Login
Botón de huella: ❌ GRIS (no hay credenciales locales aún)
```

**Paso 3:** Login con email/password
```
Email: usuario@ejemplo.com
Password: su_password
→ Entra al Dashboard
```

**Logs esperados:**
```
👤 [LOGIN_EMAIL] Perfil obtenido. Biometría habilitada: true
🔄 [LOGIN_EMAIL] Usuario tiene biometría habilitada, guardando tokens de sesión activa...
✅ [LOGIN_EMAIL] Credenciales biométricas guardadas (tokens VÁLIDOS de sesión activa)
📱 [LOGIN_EMAIL] Dispositivo no registrado, registrando...
✅ [LOGIN_EMAIL] Dispositivo registrado en user_devices
```

**Paso 4:** Verificar estado
```
Dashboard → Menú → Configurar Biometría
Estado: "Biometría Habilitada" ✅
```

**Paso 5:** Logout
```
Dashboard → Logout
Botón de huella: ✅ AZUL
```

**Paso 6:** Login biométrico
```
Click en botón de huella
→ Entra al Dashboard ✅
```

---

## 📊 Verificaciones en BD

### Ver estado de un usuario
```sql
SELECT
  id,
  email,
  biometric_enabled,
  device_id,
  created_at,
  updated_at
FROM users
WHERE email = 'tu_email@ejemplo.com';
```

### Ver dispositivos de un usuario
```sql
SELECT
  d.id,
  d.device_id,
  d.device_name,
  d.device_model,
  d.biometric_enabled,
  d.is_active,
  d.last_used_at,
  d.registered_at
FROM user_devices d
JOIN users u ON u.id = d.user_id
WHERE u.email = 'tu_email@ejemplo.com'
ORDER BY d.last_used_at DESC;
```

### Ver auditoría de dispositivos
```sql
SELECT
  da.action,
  da.device_id,
  da.created_at,
  da.details
FROM device_audit_log da
JOIN users u ON u.id = da.user_id
WHERE u.email = 'tu_email@ejemplo.com'
ORDER BY da.created_at DESC
LIMIT 10;
```

---

## ✅ Checklist de Éxito

### Flujo Habilitar
- [ ] Registro exitoso
- [ ] Login con email exitoso
- [ ] Habilitar biometría exitoso (mensaje de éxito)
- [ ] Dispositivo aparece en "Mis Dispositivos"
- [ ] BD actualizada: `biometric_enabled = true`
- [ ] BD actualizada: registro en `user_devices`

### Flujo Logout/Login Email
- [ ] Logout no borra credenciales (pero sí las invalida)
- [ ] Login biométrico falla (esperado)
- [ ] Login con email guarda NUEVOS tokens
- [ ] Logs muestran "tokens VÁLIDOS de sesión activa"
- [ ] Botón biométrico se pone AZUL después de login email

### Flujo Login Biométrico
- [ ] Logout
- [ ] Botón biométrico AZUL
- [ ] Login biométrico exitoso
- [ ] Logs muestran "Sesión refrescada exitosamente"
- [ ] Entra al Dashboard

### Flujo Deshabilitar
- [ ] Deshabilitar biometría exitoso
- [ ] Logs muestran "Dispositivo desactivado"
- [ ] BD actualizada: `biometric_enabled = false`
- [ ] BD actualizada: `is_active = false` en user_devices
- [ ] Logout → Botón GRIS
- [ ] Login biométrico no disponible

---

## 🐛 Problemas Conocidos (Resueltos)

### ❌ "Auth session missing!" después de logout
**CAUSA:** Tokens invalidados por logout
**SOLUCIÓN:** Login con email guarda nuevos tokens válidos

### ❌ Botón biométrico gris después de habilitar
**CAUSA:** No se guardaban credenciales locales correctamente
**SOLUCIÓN:** enableBiometricForCurrentUser() guarda todas las credenciales

### ❌ Deshabilitar no actualiza BD
**CAUSA:** No se llamaba a deactivateDevice()
**SOLUCIÓN:** disableBiometricForCurrentUser() ahora actualiza BD correctamente

---

## 📞 Si Algo Falla

1. **Limpiar completamente:**
```bash
flutter clean
flutter pub get
rm -rf build/
flutter run
```

2. **Verificar BD:**
- Ejecutar consultas SQL de verificación
- Verificar que `updated_at` existe en tabla `users`
- Verificar que tabla `user_devices` existe

3. **Resetear usuario:**
```sql
-- Limpiar biometría de un usuario
UPDATE users
SET biometric_enabled = false, device_id = null
WHERE email = 'tu_email@ejemplo.com';

-- Desactivar todos sus dispositivos
UPDATE user_devices
SET is_active = false, biometric_enabled = false
WHERE user_id = (SELECT id FROM users WHERE email = 'tu_email@ejemplo.com');
```

4. **Ver logs completos:**
```bash
flutter logs | grep -E "(BIOMETRIC|LOGIN|DEVICE)"
```

---

**Fecha:** 2025-11-02
**Versión:** 2.0.0
**Estado:** ✅ FLUJO COMPLETAMENTE CORREGIDO
