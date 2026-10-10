package com.example.backend.dto;

import java.time.LocalDate;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Resumen de una operación de actividad (creación masiva: mismo
 * título y fecha de creación) dentro de una comunidad. Se usa para
 * elegir la actividad cuyo expediente se desea generar.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ActividadComunidadResumenDTO {
    /** Actividad de referencia de la operación (cualquiera del grupo). */
    private Long actividadId;
    private String titulo;
    private LocalDate fechaCreacion;
    private LocalDate fechaLimite;
    private Long comunidadId;
    private String comunidadNombre;
    private int totalAsignadas;
    private int totalAprobadas;
}
