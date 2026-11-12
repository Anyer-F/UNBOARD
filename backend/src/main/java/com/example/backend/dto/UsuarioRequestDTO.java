package com.example.backend.dto;

import java.time.LocalDate;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UsuarioRequestDTO {

    private String nombre;
    private String apellido;
    private String correo;
    private String password;
    private Long rolId;
    private String telefono;
    private String direccion;
    private LocalDate fechaNacimiento;
}
