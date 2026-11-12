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
public class ModuloResponseDTO {

    private Long id;
    private Long comunidadId;
    private String nombre;
    private String descripcion;
    private Integer orden;
    private long totalActividades;
    private LocalDateTime fechaCreacion;
}
