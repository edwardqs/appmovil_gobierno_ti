-- Script para corregir la tabla de riesgos en Supabase
-- Ejecutar este script en el SQL Editor de Supabase

-- 1. Agregar la columna image_paths a la tabla risks
ALTER TABLE risks 
ADD COLUMN IF NOT EXISTS image_paths TEXT[] DEFAULT '{}';

-- 2. Agregar comentario a la columna para documentación
COMMENT ON COLUMN risks.image_paths IS 'URLs de las imágenes asociadas al riesgo, almacenadas en Supabase Storage';

-- 3. Verificar que la columna se creó correctamente
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'risks' AND column_name = 'image_paths';

-- 4. Crear buckets de Storage si no existen (ejecutar uno por uno)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('images', 'images', true) 
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) 
VALUES ('risk-attachments', 'risk-attachments', true) 
ON CONFLICT (id) DO NOTHING;

-- 5. Configurar políticas de Storage para los buckets (permitir a usuarios autenticados)
-- Política para subir archivos
CREATE POLICY "Usuarios autenticados pueden subir imágenes" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id IN ('images', 'risk-attachments') AND 
  auth.role() = 'authenticated'
);

-- Política para ver archivos
CREATE POLICY "Usuarios autenticados pueden ver imágenes" ON storage.objects
FOR SELECT USING (
  bucket_id IN ('images', 'risk-attachments') AND 
  auth.role() = 'authenticated'
);

-- 6. Verificar que los buckets se crearon
SELECT * FROM storage.buckets WHERE id IN ('images', 'risk-attachments');