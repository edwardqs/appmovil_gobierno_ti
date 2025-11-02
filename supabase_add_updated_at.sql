-- ============================================================================
-- SCRIPT: Agregar columna updated_at a tabla users
-- ============================================================================
-- Este script soluciona el error: record "new" has no field "updated_at"
-- Ejecutar en SQL Editor de Supabase
-- ============================================================================

-- PASO 1: Agregar columna updated_at a la tabla users
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- PASO 2: Inicializar updated_at = created_at para registros existentes
UPDATE public.users
SET updated_at = created_at
WHERE updated_at IS NULL;

-- PASO 3: Crear o reemplazar función para auto-actualizar updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- PASO 4: Crear trigger para auto-actualizar updated_at en cada UPDATE
DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- PASO 5: Verificar que la columna existe
SELECT
  'VERIFICACIÓN: Columna updated_at agregada' as info,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'users'
  AND table_schema = 'public'
  AND column_name IN ('created_at', 'updated_at')
ORDER BY column_name;

-- PASO 6: Verificar que el trigger existe
SELECT
  'VERIFICACIÓN: Trigger de updated_at' as info,
  trigger_name,
  event_manipulation,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'users'
  AND trigger_schema = 'public'
  AND trigger_name = 'update_users_updated_at';

SELECT '✅ Columna updated_at agregada y configurada exitosamente' as status;
