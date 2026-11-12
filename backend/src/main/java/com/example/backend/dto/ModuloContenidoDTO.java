package com.example.backend.dto;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Módulo visto por el apadrinado con sus actividades separadas.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ModuloContenidoDTO {

    private ModuloResponseDTO modulo;
    private List<AsignacionResponseDTO> enProceso;
    private List<AsignacionResponseDTO> realizadas;
    private List<AsignacionResponseDTO> anuncios;
    private List<AsignacionResponseDTO> material;
}
