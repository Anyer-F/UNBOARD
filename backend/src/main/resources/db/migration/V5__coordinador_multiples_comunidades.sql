-- FASE F: múltiples comunidades por coordinador.
-- Relación N:M entre coordinador y comunidad (tabla intermedia).
-- La columna coordinador.id_comunidad se conserva como "comunidad principal"
-- por compatibilidad con la aplicación móvil.

CREATE TABLE IF NOT EXISTS coordinador_comunidad (
    id_coordinador BIGINT NOT NULL,
    id_comunidad BIGINT NOT NULL,
    CONSTRAINT pk_coordinador_comunidad PRIMARY KEY (id_coordinador, id_comunidad),
    CONSTRAINT fk_cc_coordinador FOREIGN KEY (id_coordinador)
        REFERENCES coordinador (id) ON DELETE CASCADE,
    CONSTRAINT fk_cc_comunidad FOREIGN KEY (id_comunidad)
        REFERENCES comunidad (id) ON DELETE CASCADE
);

-- Semilla: la comunidad principal de cada coordinador también
-- queda registrada como comunidad bajo su responsabilidad.
INSERT INTO coordinador_comunidad (id_coordinador, id_comunidad)
SELECT c.id, c.id_comunidad
FROM coordinador c
WHERE c.id_comunidad IS NOT NULL
ON CONFLICT (id_coordinador, id_comunidad) DO NOTHING;
