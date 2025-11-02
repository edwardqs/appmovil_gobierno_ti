-- ============================================================================
-- SCRIPT DE CORRECCIÓN: Fix para trigger de auditoría
-- ============================================================================
-- Este script corrige el error: record "new" has no field "updated_at"
-- Ejecutar en SQL Editor de Supabase
-- ============================================================================

-- PASO 1: Eliminar el trigger existente (si existe)
DROP TRIGGER IF EXISTS audit_device_changes ON public.user_devices;

-- PASO 2: Eliminar la función existente (si existe)
DROP FUNCTION IF EXISTS public.log_device_action();

-- PASO 3: Recrear la función de auditoría correctamente
CREATE OR REPLACE FUNCTION public.log_device_action()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Solo registrar en auditoría, sin acceder a campos que no existen
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

-- PASO 4: Recrear el trigger
CREATE TRIGGER audit_device_changes
  AFTER INSERT OR UPDATE ON public.user_devices
  FOR EACH ROW
  EXECUTE FUNCTION public.log_device_action();

-- PASO 5: Verificación
SELECT 'Trigger corregido exitosamente' as status;

-- PASO 6: Verificar que el trigger existe
SELECT
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'audit_device_changes';
