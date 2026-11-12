package com.example.backend.dto;

import java.time.LocalDate;
import java.util.List;

import com.example.backend.entity.EstadoExpediente;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Expediente digital del apadrinado (solo coordinador).
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ExpedienteResponseDTO {

    private Long id;
    private String codigo;
    private EstadoExpediente estado;
    private LocalDate fechaCreacion;
    private ApadrinadoResponseDTO apadrinado;
    private List<AsignacionResponseDTO> actividades;
    private List<DocumentoResponseDTO> documentos;
    private List<DocumentoResponseDTO> fotografias;
    private List<CartaResponseDTO> cartas;
    private List<ObservacionResponseDTO> observaciones;
    private Integer totalActividades;
    private Integer totalAprobadas;
    private Integer totalDocumentos;
    private Integer totalFotografias;
    private Integer totalCartas;
}
