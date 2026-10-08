package com.example.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ApadrinadoRequestDTO {
    private Long usuarioId;
    private Long coordinadorId;
    private Long comunidadId;

    // Campos para registro directo del usuario apadrinado
    private String nombre;
    private String correo;
    private String password;
}
