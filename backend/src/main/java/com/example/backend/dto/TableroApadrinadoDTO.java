package com.example.backend.dto;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Tareas pendientes del apadrinado, ordenadas por fecha límite.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TableroApadrinadoDTO {

    private List<AsignacionResponseDTO> pendientes;
    private long correcciones;
    private long proximasAVencer;
    private long realizadas;
    private long anunciosNuevos;
}
