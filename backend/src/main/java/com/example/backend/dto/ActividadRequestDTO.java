package com.example.backend.dto;

import java.time.LocalDate;
import java.util.List;

import com.example.backend.entity.TipoActividad;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Creación / edición de una actividad.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ActividadRequestDTO {

    private TipoActividad tipo;
    private String titulo;
    private String descripcion;
    private String instrucciones;
    private LocalDate fechaLimite;
    private Boolean requiereDocumento;
    private Boolean requiereFotografia;
    private Boolean requiereCarta;
    private String otrosRequisitos;
    private Long comunidadId;
    private Long moduloId;
    /** true: toda la comunidad; false: los apadrinados de apadrinadoIds. */
    private Boolean asignarAComunidad;
    private List<Long> apadrinadoIds;
}
