package com.example.backend.dto;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Lista ordenada de IDs (ej. nuevo orden de los módulos) o módulo destino.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class IdsRequestDTO {

    private List<Long> ids;
    private Long moduloId;
}
