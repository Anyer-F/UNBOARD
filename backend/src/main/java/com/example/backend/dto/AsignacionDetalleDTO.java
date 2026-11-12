package com.example.backend.dto;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Asignación con la actividad y todas las versiones de la entrega.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AsignacionDetalleDTO {

    private AsignacionResponseDTO asignacion;
    private ActividadResponseDTO actividad;
    private List<EntregaResponseDTO> entregas;
    /** El apadrinado puede modificar y enviar su entrega. */
    private boolean editable;
}
