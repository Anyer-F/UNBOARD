-- Migración: códigos de acceso a comunidades y solicitudes de incorporación
-- Aplicar contra la base de datos UNBOUND (PostgreSQL)

CREATE TABLE IF NOT EXISTS codigo_acceso (
    id BIGSERIAL PRIMARY KEY,
    codigo VARCHAR(20) NOT NULL,
    id_comunidad BIGINT NOT NULL REFERENCES comunidad(id),
    id_coordinador BIGINT NOT NULL REFERENCES coordinador(id),
    activo BOOLEAN NOT NULL,
    fecha_creacion TIMESTAMP NOT NULL,
    fecha_expiracion TIMESTAMP,
    max_usos INTEGER,
    usos INTEGER NOT NULL,
    descripcion VARCHAR(255),
    CONSTRAINT uk_codigo_acceso UNIQUE (codigo)
);

CREATE TABLE IF NOT EXISTS solicitud_incorporacion (
    id BIGSERIAL PRIMARY KEY,
    id_usuario BIGINT NOT NULL REFERENCES usuario(id),
    id_comunidad BIGINT NOT NULL REFERENCES comunidad(id),
    codigo VARCHAR(20),
    estado VARCHAR(20) NOT NULL,
    fecha_solicitud TIMESTAMP NOT NULL,
    fecha_respuesta TIMESTAMP,
    id_coordinador BIGINT REFERENCES coordinador(id),
    observaciones VARCHAR(500)
);

CREATE INDEX IF NOT EXISTS idx_solicitud_pendiente
    ON solicitud_incorporacion (id_comunidad, estado);
CREATE INDEX IF NOT EXISTS idx_solicitud_usuario
    ON solicitud_incorporacion (id_usuario);
