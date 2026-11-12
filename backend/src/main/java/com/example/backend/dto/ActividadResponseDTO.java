package com.example.backend.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import com.example.backend.entity.TipoActividad;

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
    private TipoActividad tipo;
    private String titulo;
    private String descripcion;
    private String instrucciones;
    private LocalDateTime fechaCreacion;
    private LocalDateTime fechaActualizacion;
    private LocalDate fechaLimite;
    private Boolean requiereDocumento;
    private Boolean requiereFotografia;
    private Boolean requiereCarta;
    private String otrosRequisitos;
    private Long comunidadId;
    private String comunidadNombre;
    private Long moduloId;
    private String moduloNombre;
    private Long coordinadorId;
    private String coordinadorNombre;
    private Boolean asignadaAComunidad;
    private Boolean eliminada;
    private List<DocumentoResponseDTO> adjuntos;
    private ResumenAvanceDTO resumen;
}
