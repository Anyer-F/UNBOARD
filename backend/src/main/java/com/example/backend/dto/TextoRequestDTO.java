package com.example.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Texto libre: comentario, sugerencias u observación.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TextoRequestDTO {

    private String texto;
    private Long asignacionId;
}
