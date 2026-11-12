package com.example.backend.dto;

import java.time.LocalDateTime;
import java.util.List;

import com.example.backend.entity.EstadoEntrega;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EntregaResponseDTO {

    private Long id;
    private Long asignacionId;
    private Integer version;
    private EstadoEntrega estado;
    private String comentario;
    private LocalDateTime fechaCreacion;
    private LocalDateTime fechaEnvio;
    private LocalDateTime fechaRevision;
    private String revisorNombre;
    private List<DocumentoResponseDTO> documentos;
    private List<CartaResponseDTO> cartas;
    private List<SugerenciaResponseDTO> sugerencias;
}
