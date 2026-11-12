package com.example.backend.entity;

/**
 * Estado de una actividad para cada apadrinado asignado (asignación).
 *
 * Tarea: PENDIENTE → EN_PROGRESO → ENVIADO → EN_REVISION →
 * (CORRECCION_SOLICITADA → ENVIADO ...) → APROBADO; VENCIDO si la
 * fecha límite pasa sin que la entrega se haya enviado.
 *
 * Anuncio y Material de apoyo: PUBLICADO → VISTO.
 */
public enum EstadoActividad {
    PENDIENTE,
    EN_PROGRESO,
    ENVIADO,
    EN_REVISION,
    CORRECCION_SOLICITADA,
    APROBADO,
    VENCIDO,
    PUBLICADO,
    VISTO
}
