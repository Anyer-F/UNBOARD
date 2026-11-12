package com.example.backend.dto;

import java.time.LocalDate;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Datos del perfil que el propio usuario puede actualizar.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PerfilRequestDTO {

    private String nombre;
    private String apellido;
    private String telefono;
    private String direccion;
    private LocalDate fechaNacimiento;
}
