-- ============================================================================
-- SCRIPT DE MIGRACIÓN: SOPORTE PARA MÚLTIPLES DISPOSITIVOS
-- ============================================================================
-- Este script permite que un usuario pueda tener biometría habilitada en
-- múltiples dispositivos simultáneamente sin perder la sesión.
--
-- Ejecutar en el SQL Editor de Supabase
-- ============================================================================

-- PASO 1: Crear tabla user_devices para gestionar múltiples dispositivos
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_devices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  device_name TEXT,
  device_model TEXT,
  os_version TEXT,
  biometric_enabled BOOLEAN DEFAULT true,
  last_used_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  registered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true,

  -- Constraints
  CONSTRAINT unique_user_device UNIQUE(user_id, device_id)
);

-- Índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON public.user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_device_id ON public.user_devices(device_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_active ON public.user_devices(user_id, is_active);

-- Comentarios
COMMENT ON TABLE public.user_devices IS 'Tabla para gestionar múltiples dispositivos por usuario con biometría habilitada';
COMMENT ON COLUMN public.user_devices.device_id IS 'ID único del dispositivo (generado por device_info_plus)';
COMMENT ON COLUMN public.user_devices.device_name IS 'Nombre amigable del dispositivo (ej: iPhone 14, Samsung S23)';
COMMENT ON COLUMN public.user_devices.biometric_enabled IS 'Si la biometría está habilitada en este dispositivo';
COMMENT ON COLUMN public.user_devices.is_active IS 'Si el dispositivo está activo (permite desactivar sin eliminar)';

-- ============================================================================
-- PASO 2: Migrar datos existentes de users.device_id a user_devices
-- ============================================================================

INSERT INTO public.user_devices (user_id, device_id, device_name, biometric_enabled, registered_at, last_used_at)
SELECT
  id as user_id,
  device_id,
  'Dispositivo principal' as device_name,
  biometric_enabled,
  created_at as registered_at,
  created_at as last_used_at  -- ✅ CORREGIDO: Usar created_at en lugar de updated_at
FROM public.users
WHERE device_id IS NOT NULL
  AND biometric_enabled = true
ON CONFLICT (user_id, device_id) DO NOTHING;

-- ============================================================================
-- PASO 3: Row Level Security (RLS) para user_devices
-- ============================================================================

ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

-- Política: Los usuarios solo pueden ver sus propios dispositivos
CREATE POLICY "Users can view their own devices"
  ON public.user_devices
  FOR SELECT
  USING (auth.uid() = user_id);

-- Política: Los usuarios pueden insertar sus propios dispositivos
CREATE POLICY "Users can insert their own devices"
  ON public.user_devices
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Política: Los usuarios pueden actualizar sus propios dispositivos
CREATE POLICY "Users can update their own devices"
  ON public.user_devices
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Política: Los usuarios pueden eliminar sus propios dispositivos
CREATE POLICY "Users can delete their own devices"
  ON public.user_devices
  FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- PASO 4: Función para registrar/actualizar dispositivo
-- ============================================================================

CREATE OR REPLACE FUNCTION public.register_user_device(
  p_user_id UUID,
  p_device_id TEXT,
  p_device_name TEXT DEFAULT NULL,
  p_device_model TEXT DEFAULT NULL,
  p_os_version TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_device_record RECORD;
  v_result JSON;
BEGIN
  -- Verificar que el usuario autenticado es el mismo que el p_user_id
  IF auth.uid() != p_user_id THEN
    RETURN json_build_object(
      'success', false,
      'message', 'No autorizado para registrar dispositivos de otro usuario'
    );
  END IF;

  -- Insertar o actualizar dispositivo
  INSERT INTO public.user_devices (
    user_id,
    device_id,
    device_name,
    device_model,
    os_version,
    biometric_enabled,
    is_active,
    last_used_at,
    registered_at
  )
  VALUES (
    p_user_id,
    p_device_id,
    COALESCE(p_device_name, 'Dispositivo ' || SUBSTRING(p_device_id, 1, 8)),
    p_device_model,
    p_os_version,
    true,
    true,
    NOW(),
    NOW()
  )
  ON CONFLICT (user_id, device_id)
  DO UPDATE SET
    device_name = COALESCE(EXCLUDED.device_name, user_devices.device_name),
    device_model = COALESCE(EXCLUDED.device_model, user_devices.device_model),
    os_version = COALESCE(EXCLUDED.os_version, user_devices.os_version),
    biometric_enabled = true,
    is_active = true,
    last_used_at = NOW()
  RETURNING * INTO v_device_record;

  v_result := json_build_object(
    'success', true,
    'message', 'Dispositivo registrado exitosamente',
    'device', row_to_json(v_device_record)
  );

  RETURN v_result;
END;
$$;

-- ============================================================================
-- PASO 5: Función para actualizar last_used_at de un dispositivo
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_device_last_used(
  p_user_id UUID,
  p_device_id TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.user_devices
  SET last_used_at = NOW()
  WHERE user_id = p_user_id
    AND device_id = p_device_id
    AND is_active = true;

  RETURN FOUND;
END;
$$;

-- ============================================================================
-- PASO 6: Función para desactivar un dispositivo
-- ============================================================================

CREATE OR REPLACE FUNCTION public.deactivate_device(
  p_user_id UUID,
  p_device_id TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verificar autorización
  IF auth.uid() != p_user_id THEN
    RETURN json_build_object(
      'success', false,
      'message', 'No autorizado'
    );
  END IF;

  UPDATE public.user_devices
  SET
    is_active = false,
    biometric_enabled = false
  WHERE user_id = p_user_id
    AND device_id = p_device_id;

  IF FOUND THEN
    RETURN json_build_object(
      'success', true,
      'message', 'Dispositivo desactivado exitosamente'
    );
  ELSE
    RETURN json_build_object(
      'success', false,
      'message', 'Dispositivo no encontrado'
    );
  END IF;
END;
$$;

-- ============================================================================
-- PASO 7: Función para verificar si un dispositivo está registrado y activo
-- ============================================================================

CREATE OR REPLACE FUNCTION public.is_device_registered(
  p_user_id UUID,
  p_device_id TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1
    FROM public.user_devices
    WHERE user_id = p_user_id
      AND device_id = p_device_id
      AND is_active = true
      AND biometric_enabled = true
  ) INTO v_exists;

  RETURN v_exists;
END;
$$;

-- ============================================================================
-- PASO 8: Auditoría de dispositivos (opcional)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.device_audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  action TEXT NOT NULL, -- 'register', 'login', 'deactivate', 'update'
  success BOOLEAN DEFAULT true,
  details JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_audit_user_id ON public.device_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_device_audit_created_at ON public.device_audit_log(created_at DESC);

ALTER TABLE public.device_audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own device audit logs"
  ON public.device_audit_log
  FOR SELECT
  USING (auth.uid() = user_id);

-- ============================================================================
-- PASO 9: Trigger para auditoría automática
-- ============================================================================

CREATE OR REPLACE FUNCTION public.log_device_action()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- ✅ CORREGIDO: Incluir todos los campos relevantes sin acceder a campos inexistentes
  INSERT INTO public.device_audit_log (user_id, device_id, action, details)
  VALUES (
    NEW.user_id,
    NEW.device_id,
    TG_OP,
    jsonb_build_object(
      'device_name', NEW.device_name,
      'device_model', NEW.device_model,
      'os_version', NEW.os_version,
      'biometric_enabled', NEW.biometric_enabled,
      'is_active', NEW.is_active,
      'last_used_at', NEW.last_used_at,
      'registered_at', NEW.registered_at
    )
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER audit_device_changes
  AFTER INSERT OR UPDATE ON public.user_devices
  FOR EACH ROW
  EXECUTE FUNCTION public.log_device_action();

-- ============================================================================
-- PASO 10: Verificación final
-- ============================================================================

-- Verificar que la tabla existe
SELECT 'user_devices table created' as status
WHERE EXISTS (
  SELECT FROM information_schema.tables
  WHERE table_schema = 'public'
  AND table_name = 'user_devices'
);

-- Mostrar dispositivos migrados
SELECT
  COUNT(*) as total_devices,
  COUNT(DISTINCT user_id) as total_users
FROM public.user_devices;

-- ============================================================================
-- NOTAS IMPORTANTES
-- ============================================================================
-- 1. Este script crea una tabla user_devices que permite múltiples dispositivos
-- 2. Los datos existentes en users.device_id se migran automáticamente
-- 3. Las políticas RLS garantizan que cada usuario solo vea sus dispositivos
-- 4. Se incluye auditoría automática de cambios en dispositivos
-- 5. La columna users.device_id se mantiene por compatibilidad (deprecada)
-- 6. Ejecutar este script UNA SOLA VEZ en producción
-- ============================================================================

SELECT '✅ Migración completada exitosamente' as mensaje;
