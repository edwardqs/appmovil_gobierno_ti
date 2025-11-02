-- ========================================
-- SCRIPT PARA CORREGIR SUPABASE - EJECUTAR PASO A PASO
-- ========================================

-- PASO 1: Agregar columna image_paths a la tabla risks
-- Ejecutar este comando primero:
ALTER TABLE risks 
ADD COLUMN IF NOT EXISTS image_paths TEXT[] DEFAULT '{}';

-- PASO 2: Verificar que la columna se creó
-- Ejecutar para confirmar:
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'risks' AND column_name = 'image_paths';

-- PASO 3: Crear bucket 'images' 
-- Ejecutar este comando:
INSERT INTO storage.buckets (id, name, public) 
VALUES ('images', 'images', true) 
ON CONFLICT (id) DO NOTHING;

-- PASO 4: Crear bucket 'risk-attachments'
-- Ejecutar este comando:
INSERT INTO storage.buckets (id, name, public) 
VALUES ('risk-attachments', 'risk-attachments', true) 
ON CONFLICT (id) DO NOTHING;

-- PASO 5: Verificar que los buckets se crearon
-- Ejecutar para confirmar:
SELECT id, name, public FROM storage.buckets 
WHERE id IN ('images', 'risk-attachments');

-- PASO 6: Crear política para subir archivos
-- Ejecutar este comando:
CREATE POLICY IF NOT EXISTS "Usuarios autenticados pueden subir imágenes" 
ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id IN ('images', 'risk-attachments') AND 
  auth.role() = 'authenticated'
);

-- PASO 7: Crear política para ver archivos  
-- Ejecutar este comando:
CREATE POLICY IF NOT EXISTS "Usuarios autenticados pueden ver imágenes" 
ON storage.objects
FOR SELECT USING (
  bucket_id IN ('images', 'risk-attachments') AND 
  auth.role() = 'authenticated'
);

-- PASO 8: Verificación final
-- Ejecutar para confirmar todo:
SELECT 'Columna image_paths' as tipo, 
       CASE WHEN EXISTS (
         SELECT 1 FROM information_schema.columns 
         WHERE table_name = 'risks' AND column_name = 'image_paths'
       ) THEN 'EXISTE' ELSE 'NO EXISTE' END as estado
UNION ALL
SELECT 'Bucket images' as tipo,
       CASE WHEN EXISTS (
         SELECT 1 FROM storage.buckets WHERE id = 'images'
       ) THEN 'EXISTE' ELSE 'NO EXISTE' END as estado
UNION ALL  
SELECT 'Bucket risk-attachments' as tipo,
       CASE WHEN EXISTS (
         SELECT 1 FROM storage.buckets WHERE id = 'risk-attachments'  
       ) THEN 'EXISTE' ELSE 'NO EXISTE' END as estado;