package com.example.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Avance de una actividad: cantidad de apadrinados en cada estado.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ResumenAvanceDTO {

    private long asignados;
    private long pendientes;
    private long enProgreso;
    private long enviados;
    private long enRevision;
    private long correcciones;
    private long aprobados;
    private long vencidos;
    private long publicados;
    private long vistos;
}
