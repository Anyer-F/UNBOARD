-- Migración: material de apoyo por comunidad
-- Aplicar contra la base de datos UNBOUND (PostgreSQL)

CREATE TABLE IF NOT EXISTS material_apoyo (
    id BIGSERIAL PRIMARY KEY,
    titulo VARCHAR(255) NOT NULL,
    descripcion TEXT,
    nombre_original VARCHAR(255) NOT NULL,
    nombre_almacenado VARCHAR(255) NOT NULL,
    ruta_archivo VARCHAR(500) NOT NULL,
    tipo_mime VARCHAR(100),
    tamanio_bytes BIGINT,
    fecha_subida TIMESTAMP,
    id_comunidad BIGINT NOT NULL REFERENCES comunidad(id),
    id_coordinador BIGINT NOT NULL REFERENCES coordinador(id),
    id_usuario BIGINT REFERENCES usuario(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_material_nombre_almacenado
    ON material_apoyo (nombre_almacenado);
CREATE INDEX IF NOT EXISTS idx_material_comunidad
    ON material_apoyo (id_comunidad, fecha_subida DESC);
