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
public class MaterialApoyoResponseDTO {
    private Long id;
    private String titulo;
    private String descripcion;
    private String nombreOriginal;
    private String urlDescarga;
    private String tipoMime;
    private Long tamanioBytes;
    private LocalDateTime fechaSubida;
    private Long comunidadId;
    private String comunidadNombre;
    private Long coordinadorId;
    private Long subidoPorUsuarioId;
    private String subidoPorNombre;
}
