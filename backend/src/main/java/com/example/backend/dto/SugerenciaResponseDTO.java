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
public class SugerenciaResponseDTO {

    private Long id;
    private Long entregaId;
    private Integer version;
    private String texto;
    private String autorNombre;
    private LocalDateTime fecha;
}
