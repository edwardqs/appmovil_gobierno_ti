-- ============================================================================
-- SCRIPT PARA DEPURAR PROBLEMA DE REFRESH TOKENS
-- ============================================================================
-- Ejecutar en Supabase SQL Editor para verificar el estado de los tokens
-- ============================================================================

-- Ver información de autenticación de un usuario
SELECT
  id,
  email,
  created_at,
  updated_at,
  last_sign_in_at,
  email_confirmed_at
FROM auth.users
WHERE email = 'esquispes01@gmail.com';

-- Ver sesiones activas de un usuario
SELECT
  id,
  user_id,
  created_at,
  updated_at,
  NOT_AFTER,
  factor_id
FROM auth.sessions
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'esquispes01@gmail.com')
ORDER BY created_at DESC
LIMIT 5;

-- Ver refresh tokens activos
SELECT
  token,
  user_id,
  created_at,
  updated_at,
  revoked
FROM auth.refresh_tokens
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'esquispes01@gmail.com')
  AND revoked = false
ORDER BY created_at DESC
LIMIT 5;

-- Ver TODOS los refresh tokens (incluyendo revocados)
SELECT
  token,
  user_id,
  created_at,
  updated_at,
  revoked,
  CASE
    WHEN revoked THEN '❌ REVOCADO'
    ELSE '✅ ACTIVO'
  END as estado
FROM auth.refresh_tokens
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'esquispes01@gmail.com')
ORDER BY created_at DESC
LIMIT 10;

-- Ver estado de biometría del usuario
SELECT
  id,
  email,
  biometric_enabled,
  device_id
FROM public.users
WHERE email = 'esquispes01@gmail.com';

-- Ver dispositivos registrados
SELECT
  device_id,
  device_name,
  biometric_enabled,
  is_active,
  last_used_at,
  registered_at
FROM public.user_devices
WHERE user_id = (SELECT id FROM public.users WHERE email = 'esquispes01@gmail.com')
ORDER BY last_used_at DESC;
