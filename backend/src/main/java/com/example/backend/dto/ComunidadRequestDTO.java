package com.example.backend.dto;

import com.example.backend.entity.ModoIncorporacion;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ComunidadRequestDTO {

    private String nombre;
    private String municipio;
    private String departamento;
    private ModoIncorporacion modoIncorporacion;
}
