package com.example.backend.dto;

import java.time.LocalDateTime;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CodigoAccesoResponseDTO {
    private Long id;
    private String codigo;
    private Long comunidadId;
    private String comunidadNombre;
    private Long coordinadorId;
    private Boolean activo;
    private LocalDateTime fechaCreacion;
    private LocalDateTime fechaExpiracion;
    private Integer maxUsos;
    private Integer usos;
    private String descripcion;
}
