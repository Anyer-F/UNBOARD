package com.example.backend.dto;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Detalle de una actividad para el coordinador.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ActividadDetalleDTO {

    private ActividadResponseDTO actividad;
    private List<AsignacionResponseDTO> asignaciones;
    /** Tiene entregas enviadas: eliminarla será lógica. */
    private boolean tieneEntregas;
    /** Se puede exportar PDF / ZIP (tarea con al menos una entrega aprobada). */
    private boolean exportable;
}
