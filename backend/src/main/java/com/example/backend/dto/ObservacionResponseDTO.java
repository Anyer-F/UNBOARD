package com.example.backend.dto;

import java.time.LocalDateTime;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ObservacionResponseDTO {

    private Long id;
    private Long expedienteId;
    private Long asignacionId;
    private String actividadTitulo;
    private String texto;
    private String autorNombre;
    private LocalDateTime fecha;
}
