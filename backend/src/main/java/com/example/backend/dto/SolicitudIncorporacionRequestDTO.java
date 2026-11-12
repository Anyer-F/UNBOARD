package com.example.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SolicitudIncorporacionRequestDTO {

    /** Opcional: si no se envía, se deduce del código de acceso. */
    private Long comunidadId;

    @NotBlank(message = "El código de acceso es obligatorio")
    private String codigo;
}
