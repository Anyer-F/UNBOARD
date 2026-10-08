-- Script para corregir la migración de la tabla expediente
-- Actualiza los registros existentes con estado NULL a 'ACTIVO'

UPDATE expediente SET estado = 'ACTIVO' WHERE estado IS NULL;

-- Ahora sí se puede agregar la restricción NOT NULL
ALTER TABLE expediente ALTER COLUMN estado SET NOT NULL;
