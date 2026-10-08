package com.example.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class VerificarCodigoRequestDTO {

    @NotBlank(message = "El correo electrónico es obligatorio.")
    private String correo;

    @NotBlank(message = "El código de verificación es obligatorio.")
    @Size(min = 6, max = 10, message = "El código debe tener entre 6 y 10 caracteres.")
    private String codigo;
}
