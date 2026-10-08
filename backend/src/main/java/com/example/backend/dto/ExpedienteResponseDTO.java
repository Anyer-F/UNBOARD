package com.example.backend.dto;

import java.time.LocalDate;
import java.util.List;

import com.example.backend.entity.EstadoExpediente;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ExpedienteResponseDTO {
    private Long id;
    private String codigo;
    private EstadoExpediente estado;
    private ApadrinadoResponseDTO apadrinado;
    private LocalDate fechaCreacion;
    private List<DocumentoResponseDTO> documentos;
    private List<ActividadResponseDTO> actividades;
    private Integer totalDocumentos;
    private Integer totalActividades;
}
