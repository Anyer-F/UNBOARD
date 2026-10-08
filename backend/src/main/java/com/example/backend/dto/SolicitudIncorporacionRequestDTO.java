package com.example.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SolicitudIncorporacionRequestDTO {

    @NotNull(message = "El ID de la comunidad es obligatorio")
    private Long comunidadId;

    @NotBlank(message = "El código de acceso es obligatorio")
    private String codigo;
}
