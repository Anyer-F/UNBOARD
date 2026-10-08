-- Fase E: nuevos estados de actividad (EN_REVISION, VENCIDO)
-- y nuevos tipos de notificacion (ACTIVIDAD_EN_REVISION, ACTIVIDAD_VENCIDA).
-- Las check constraints fueron creadas por Hibernate con los valores
-- originales del enum; se amplian para admitir los nuevos valores.

ALTER TABLE actividad DROP CONSTRAINT IF EXISTS actividad_estado_check;
ALTER TABLE actividad ADD CONSTRAINT actividad_estado_check
    CHECK (estado IN ('PENDIENTE', 'EN_PROCESO', 'ENTREGADA', 'EN_REVISION',
                      'APROBADA', 'CORRECCION_SOLICITADA', 'VENCIDO'));

ALTER TABLE historial_actividad DROP CONSTRAINT IF EXISTS historial_actividad_estado_anterior_check;
ALTER TABLE historial_actividad ADD CONSTRAINT historial_actividad_estado_anterior_check
    CHECK (estado_anterior IN ('PENDIENTE', 'EN_PROCESO', 'ENTREGADA', 'EN_REVISION',
                               'APROBADA', 'CORRECCION_SOLICITADA', 'VENCIDO'));

ALTER TABLE historial_actividad DROP CONSTRAINT IF EXISTS historial_actividad_estado_nuevo_check;
ALTER TABLE historial_actividad ADD CONSTRAINT historial_actividad_estado_nuevo_check
    CHECK (estado_nuevo IN ('PENDIENTE', 'EN_PROCESO', 'ENTREGADA', 'EN_REVISION',
                            'APROBADA', 'CORRECCION_SOLICITADA', 'VENCIDO'));

ALTER TABLE notificacion DROP CONSTRAINT IF EXISTS notificacion_tipo_check;
ALTER TABLE notificacion ADD CONSTRAINT notificacion_tipo_check
    CHECK (tipo IN ('NUEVA_ACTIVIDAD', 'ENTREGA_ACTIVIDAD', 'ACTIVIDAD_EN_REVISION',
                    'ACTIVIDAD_APROBADA', 'CORRECCION_SOLICITADA', 'ACTIVIDAD_VENCIDA',
                    'DOCUMENTO_SUBIDO', 'RECORDATORIO', 'ACTIVIDAD', 'GENERAL'));
