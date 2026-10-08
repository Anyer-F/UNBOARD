package com.example.backend.dto;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CoordinadorResponseDTO {
    private Long id;
    private Long usuarioId;
    private String nombre;
    private String correo;
    private Long comunidadId;
    private String comunidadNombre;
    /** FASE F: todas las comunidades bajo su responsabilidad. */
    private List<ComunidadResponseDTO> comunidades;
}
