# Estructura de Roles y Permisos - Sistema de Auditoría

## 📋 Resumen General

Este documento describe la estructura completa de roles, permisos y políticas de seguridad implementadas en el sistema de gestión de riesgos y auditoría.

## 🎭 Roles de Usuario

### 1. Auditor Junior (`auditor_junior`)
**Descripción**: Nivel básico de auditor con permisos limitados para tareas específicas asignadas.

**Permisos**:
- ✅ Ver riesgos asignados a él
- ✅ Actualizar estado de riesgos asignados
- ✅ Agregar comentarios a riesgos asignados
- ✅ Subir imágenes a riesgos asignados
- ✅ Generar análisis de IA para riesgos asignados
- ✅ Ver su propio perfil
- ✅ Actualizar su propio perfil
- ✅ Gestionar sus sesiones biométricas
- ✅ Ver sus propios logs de auditoría

**Restricciones**:
- ❌ No puede ver riesgos no asignados
- ❌ No puede asignar riesgos a otros usuarios
- ❌ No puede eliminar riesgos
- ❌ No puede ver perfiles de otros usuarios
- ❌ No puede acceder a logs de otros usuarios

### 2. Auditor Senior (`auditor_senior`)
**Descripción**: Auditor experimentado con permisos ampliados para supervisión y gestión.

**Permisos** (incluye todos los de Auditor Junior más):
- ✅ Ver todos los riesgos del sistema
- ✅ Actualizar cualquier riesgo
- ✅ Asignar riesgos a auditores junior
- ✅ Agregar comentarios a cualquier riesgo
- ✅ Cambiar estados de cualquier riesgo
- ✅ Ver lista de auditores disponibles

**Restricciones**:
- ❌ No puede eliminar riesgos
- ❌ No puede ver logs de auditoría de otros (solo gerentes)
- ❌ No puede gestionar usuarios

### 3. Gerente de Auditoría (`gerente_auditoria`)
**Descripción**: Rol administrativo con acceso completo al sistema.

**Permisos** (acceso total):
- ✅ Ver, crear, actualizar y eliminar cualquier riesgo
- ✅ Ver todos los usuarios del sistema
- ✅ Asignar riesgos a cualquier auditor
- ✅ Ver todos los logs de auditoría
- ✅ Acceder a estadísticas completas del sistema
- ✅ Gestionar configuraciones del sistema
- ✅ Ver dashboards administrativos

## 🔒 Políticas de Seguridad (RLS)

### Tabla `users`
```sql
-- Los usuarios pueden ver su propio perfil
"Los usuarios pueden ver su propio perfil"
USING (auth.uid() = id)

-- Los usuarios pueden actualizar su propio perfil  
"Los usuarios pueden actualizar su propio perfil"
USING (auth.uid() = id)

-- Los gerentes pueden ver todos los usuarios
"Los gerentes pueden ver todos los usuarios"
USING (role = 'gerente_auditoria' AND auth.uid() = id)
```

### Tabla `risks`
```sql
-- Todos pueden ver riesgos (filtrado por asignación en app)
"Todos los usuarios autenticados pueden ver riesgos"
USING (auth.role() = 'authenticated')

-- Cualquier usuario autenticado puede crear riesgos
"Los auditores pueden crear riesgos"
WITH CHECK (auth.role() = 'authenticated')

-- Solo asignados o seniors/gerentes pueden actualizar
"Los auditores asignados pueden actualizar sus riesgos"
USING (assigned_user_id = auth.uid() OR user_role IN ('auditor_senior', 'gerente_auditoria'))

-- Solo gerentes pueden eliminar
"Solo gerentes pueden eliminar riesgos"
USING (user_role = 'gerente_auditoria')
```

### Tabla `audit_logs`
```sql
-- Gerentes ven todos los logs
"Los gerentes pueden ver todos los logs"
USING (user_role = 'gerente_auditoria')

-- Usuarios ven solo sus logs
"Los usuarios pueden ver sus propios logs"
USING (user_id = auth.uid())
```

## 📊 Matriz de Permisos

| Acción | Auditor Junior | Auditor Senior | Gerente |
|--------|----------------|----------------|---------|
| Ver riesgos propios | ✅ | ✅ | ✅ |
| Ver todos los riesgos | ❌ | ✅ | ✅ |
| Crear riesgos | ✅ | ✅ | ✅ |
| Actualizar riesgos propios | ✅ | ✅ | ✅ |
| Actualizar cualquier riesgo | ❌ | ✅ | ✅ |
| Eliminar riesgos | ❌ | ❌ | ✅ |
| Asignar riesgos | ❌ | ✅ | ✅ |
| Ver usuarios | Propio | Lista auditores | Todos |
| Ver logs de auditoría | Propios | Propios | Todos |
| Gestionar biometría | Propia | Propia | Propia |
| Subir imágenes | Riesgos propios | Cualquier riesgo | Cualquier riesgo |
| Generar análisis IA | Riesgos propios | Cualquier riesgo | Cualquier riesgo |

## 🔐 Seguridad Biométrica

### Gestión de Sesiones
- Cada usuario puede habilitar/deshabilitar su propia biometría
- Los tokens biométricos se almacenan hasheados en `biometric_sessions`
- Se registra cada uso de autenticación biométrica
- Los gerentes pueden ver estadísticas de uso biométrico

### Políticas de Sesiones
```sql
-- Los usuarios gestionan solo sus sesiones biométricas
"Los usuarios pueden gestionar sus sesiones biométricas"
FOR ALL USING (user_id = auth.uid())
```

## 📈 Logging y Auditoría

### Eventos Registrados
- `login` / `logout`: Inicios y cierres de sesión
- `create_risk`: Creación de nuevos riesgos
- `update_risk`: Modificaciones a riesgos
- `assign_risk`: Asignaciones de riesgos
- `change_status`: Cambios de estado
- `add_comment`: Adición de comentarios
- `upload_image`: Subida de imágenes
- `generate_ai_analysis`: Generación de análisis IA
- `enable_biometric` / `disable_biometric`: Gestión biométrica

### Información Capturada
- Usuario que realiza la acción
- Timestamp preciso
- Detalles de la acción (JSON)
- IP y User Agent
- Estado de éxito/error

## 🎯 Flujos de Trabajo por Rol

### Flujo Auditor Junior
1. **Login** → Dashboard con riesgos asignados
2. **Seleccionar riesgo** → Ver detalles y actualizar
3. **Cambiar estado** → De "Abierto" a "En Tratamiento"
4. **Agregar evidencia** → Subir imágenes y comentarios
5. **Solicitar análisis IA** → Generar insights automáticos
6. **Finalizar** → Cambiar a "Pendiente de Revisión"

### Flujo Auditor Senior
1. **Login** → Dashboard con todos los riesgos
2. **Revisar asignaciones** → Ver carga de trabajo de junior
3. **Asignar nuevos riesgos** → Distribuir trabajo
4. **Supervisar progreso** → Revisar riesgos en tratamiento
5. **Aprobar/Rechazar** → Cambiar de "Pendiente" a "Cerrado" o devolver

### Flujo Gerente de Auditoría
1. **Login** → Dashboard ejecutivo con métricas
2. **Revisar estadísticas** → KPIs y tendencias
3. **Gestionar usuarios** → Ver perfiles y asignaciones
4. **Auditar actividad** → Revisar logs del sistema
5. **Tomar decisiones** → Basado en análisis y reportes

## 🛡️ Consideraciones de Seguridad

### Principios Aplicados
- **Principio de menor privilegio**: Cada rol tiene solo los permisos mínimos necesarios
- **Separación de responsabilidades**: Diferentes niveles de acceso y aprobación
- **Trazabilidad completa**: Todos los cambios son registrados
- **Autenticación fuerte**: Soporte biométrico opcional

### Medidas Implementadas
- Row Level Security (RLS) en todas las tablas
- Triggers automáticos para logging
- Validación de datos a nivel de base de datos
- Encriptación de tokens biométricos
- Políticas granulares por tabla y operación

## 📝 Configuración Inicial

### Pasos para Implementar
1. **Ejecutar script SQL** en Supabase
2. **Crear usuario administrador** inicial
3. **Configurar políticas de Storage** para imágenes
4. **Establecer variables de entorno** en la app
5. **Probar flujos de cada rol** antes de producción

### Variables de Entorno Requeridas
```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu-clave-anonima
SUPABASE_SERVICE_ROLE_KEY=tu-clave-servicio (solo backend)
```

## 🔄 Mantenimiento y Monitoreo

### Tareas Regulares
- Revisar logs de auditoría semanalmente
- Monitorear uso de sesiones biométricas
- Verificar integridad de asignaciones
- Analizar patrones de uso por rol

### Métricas Importantes
- Tiempo promedio de resolución por rol
- Distribución de riesgos por auditor
- Frecuencia de uso de análisis IA
- Tasa de adopción biométrica

---

**Nota**: Esta estructura de permisos está diseñada para ser escalable y segura. Cualquier modificación debe ser evaluada cuidadosamente para mantener la integridad del sistema.