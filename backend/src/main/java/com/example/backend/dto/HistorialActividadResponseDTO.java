package com.example.backend.dto;

import java.time.LocalDateTime;

import com.example.backend.entity.EntidadHistorial;
import com.example.backend.entity.EstadoActividad;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HistorialActividadResponseDTO {

    private Long id;
    private EntidadHistorial entidad;
    private Long idEntidad;
    private String referencia;
    private Long actividadId;
    private String actividadTitulo;
    private Long asignacionId;
    private Long apadrinadoId;
    private String apadrinadoNombre;
    private Long comunidadId;
    private EstadoActividad estadoAnterior;
    private EstadoActividad estadoNuevo;
    private String accion;
    private String observaciones;
    private Long modificadoPorUsuarioId;
    private String modificadoPorNombre;
    private String modificadoPorRol;
    private LocalDateTime fechaHora;
}
