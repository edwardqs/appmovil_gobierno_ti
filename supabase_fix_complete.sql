-- ============================================================================
-- SCRIPT DE LIMPIEZA Y CORRECCIÓN COMPLETA
-- ============================================================================
-- Este script elimina TODOS los triggers problemáticos y los recrea correctamente
-- Ejecutar en SQL Editor de Supabase
-- ============================================================================

-- ============================================================================
-- PASO 1: Eliminar TODOS los triggers de user_devices
-- ============================================================================
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT trigger_name
              FROM information_schema.triggers
              WHERE event_object_table = 'user_devices'
              AND trigger_schema = 'public')
    LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || r.trigger_name || ' ON public.user_devices CASCADE';
    END LOOP;
END $$;

-- ============================================================================
-- PASO 2: Eliminar TODOS los triggers de users que puedan causar problemas
-- ============================================================================
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT trigger_name
              FROM information_schema.triggers
              WHERE event_object_table = 'users'
              AND trigger_schema = 'public'
              AND trigger_name LIKE '%audit%')
    LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || r.trigger_name || ' ON public.users CASCADE';
    END LOOP;
END $$;

-- ============================================================================
-- PASO 3: Eliminar funciones problemáticas
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_device_action() CASCADE;
DROP FUNCTION IF EXISTS public.handle_updated_at() CASCADE;
DROP FUNCTION IF EXISTS public.update_updated_at_column() CASCADE;

-- ============================================================================
-- PASO 4: Recrear función de auditoría CORRECTA (SIN updated_at)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_device_action()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  BEGIN
    -- Intentar insertar en auditoría, pero no fallar si hay error
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
        'is_active', NEW.is_active
      )
    );
  EXCEPTION
    WHEN OTHERS THEN
      -- Si falla la auditoría, no fallar el INSERT/UPDATE principal
      RAISE WARNING 'Error en auditoría de dispositivo: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$;

-- ============================================================================
-- PASO 5: Recrear trigger SOLO para user_devices
-- ============================================================================
CREATE TRIGGER audit_device_changes
  AFTER INSERT OR UPDATE ON public.user_devices
  FOR EACH ROW
  EXECUTE FUNCTION public.log_device_action();

-- ============================================================================
-- PASO 6: Verificar que NO existen triggers problemáticos
-- ============================================================================
SELECT
  'VERIFICACIÓN: Triggers en user_devices' as info,
  trigger_name,
  event_manipulation
FROM information_schema.triggers
WHERE event_object_table = 'user_devices'
  AND trigger_schema = 'public';

SELECT
  'VERIFICACIÓN: Triggers en users' as info,
  trigger_name,
  event_manipulation
FROM information_schema.triggers
WHERE event_object_table = 'users'
  AND trigger_schema = 'public';

-- ============================================================================
-- PASO 7: Limpiar sesiones y credenciales (opcional)
-- ============================================================================
-- Si quieres forzar a todos a hacer login de nuevo, ejecuta:
-- TRUNCATE auth.sessions CASCADE;

SELECT '✅ Limpieza y corrección completada exitosamente' as status;
