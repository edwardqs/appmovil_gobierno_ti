-- ============================================================================
-- SCRIPT PARA IDENTIFICAR TRIGGERS PROBLEMÁTICOS
-- ============================================================================
-- Ejecutar en Supabase SQL Editor para ver TODOS los triggers
-- ============================================================================

-- 1. Ver TODOS los triggers en la tabla users
SELECT
  'TRIGGERS EN TABLA USERS' as tabla,
  trigger_name,
  event_manipulation,
  action_statement,
  action_orientation,
  action_timing
FROM information_schema.triggers
WHERE event_object_table = 'users'
  AND trigger_schema = 'public'
ORDER BY trigger_name;

-- 2. Ver TODOS los triggers en la tabla user_devices
SELECT
  'TRIGGERS EN TABLA USER_DEVICES' as tabla,
  trigger_name,
  event_manipulation,
  action_statement,
  action_orientation,
  action_timing
FROM information_schema.triggers
WHERE event_object_table = 'user_devices'
  AND trigger_schema = 'public'
ORDER BY trigger_name;

-- 3. Ver TODAS las funciones que mencionan "updated_at"
SELECT
  'FUNCIONES CON UPDATED_AT' as tipo,
  routine_name,
  routine_type,
  routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_definition LIKE '%updated_at%'
ORDER BY routine_name;

-- 4. Ver estructura de la tabla users
SELECT
  'COLUMNAS DE TABLA USERS' as info,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'users'
  AND table_schema = 'public'
ORDER BY ordinal_position;
