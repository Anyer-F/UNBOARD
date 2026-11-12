package com.example.backend.dto;

import java.time.LocalDateTime;

import com.example.backend.entity.EstadoActividad;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Estado de una actividad para un apadrinado.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AsignacionResponseDTO {

    private Long id;
    private Long actividadId;
    private Long apadrinadoId;
    private String apadrinadoNombre;
    private EstadoActividad estado;
    private LocalDateTime fechaAsignacion;
    private LocalDateTime fechaInicio;
    private LocalDateTime fechaEnvio;
    private LocalDateTime fechaAprobacion;
    private LocalDateTime fechaVisto;
    private Integer versionActual;
    private String ultimaSugerencia;
    /** Fecha límite dentro de los próximos días. */
    private boolean proximaAVencer;
    private ActividadResponseDTO actividad;
}
