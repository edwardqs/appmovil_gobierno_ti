-- Query para verificar el estado de las sesiones biométricas
-- Ejecuta esta consulta en tu dashboard de Supabase

SELECT 
    bs.id,
    bs.user_id,
    bs.device_id,
    bs.is_active,
    bs.enabled_at,
    bs.last_used_at,
    bs.disabled_at,
    u.email,
    u.name
FROM biometric_sessions bs
JOIN users u ON bs.user_id = u.id
ORDER BY bs.enabled_at DESC;

-- También puedes filtrar por un usuario específico:
-- WHERE u.email = 'esquispes01@gmail.com'

-- O ver solo las sesiones activas:
-- WHERE bs.is_active = true