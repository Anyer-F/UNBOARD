package com.example.backend.dto;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Comunidad del apadrinado con su coordinador y sus módulos.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MiComunidadDTO {

    private ComunidadResponseDTO comunidad;
    private String coordinadorNombre;
    private String coordinadorCorreo;
    private List<ModuloContenidoDTO> modulos;
}
