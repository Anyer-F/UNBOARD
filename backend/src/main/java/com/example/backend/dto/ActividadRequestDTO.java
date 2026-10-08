package com.example.backend.dto;

import java.time.LocalDate;
import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ActividadRequestDTO {
    private String titulo;
    private String descripcion;
    private LocalDate fechaLimite;
    private Boolean requiereDocumento;
    private Boolean requiereFotografia;
    private Long coordinadorId;
    private Long apadrinadoId; // Para asignación individual
    private List<Long> apadrinadoIds; // Para asignación múltiple (opcional)
}
