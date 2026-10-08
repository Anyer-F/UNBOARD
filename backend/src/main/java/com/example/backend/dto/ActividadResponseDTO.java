package com.example.backend.dto;

import java.time.LocalDate;

import com.example.backend.entity.EstadoActividad;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ActividadResponseDTO {
    private Long id;
    private String titulo;
    private String descripcion;
    private LocalDate fechaCreacion;
    private LocalDate fechaLimite;
    private Boolean requiereDocumento;
    private Boolean requiereFotografia;
    private EstadoActividad estado;
    private String observaciones;
    private Long coordinadorId;
    private String coordinadorNombre;
    private Long apadrinadoId;
    private String apadrinadoNombre;
}
