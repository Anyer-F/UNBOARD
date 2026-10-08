package com.example.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LoginResponseDTO {
    private String token;
    @Builder.Default
    private String tokenType = "Bearer";
    private Long usuarioId;
    private String nombre;
    private String correo;
    private String rol;
    private Long coordinadorId;
    private Long apadrinadoId;
}
