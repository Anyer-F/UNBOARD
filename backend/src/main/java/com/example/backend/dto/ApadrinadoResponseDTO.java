package com.example.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ApadrinadoResponseDTO {
    private Long id;
    private Long usuarioId;
    private String nombre;
    private String correo;
    private Long coordinadorId;
    private String coordinadorNombre;
    private Long comunidadId;
    private String comunidadNombre;
}
