package com.example.backend.dto;

import java.time.LocalDateTime;

import com.example.backend.entity.TipoDocumento;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DocumentoResponseDTO {
    private Long id;
    private String nombreOriginal;
    private String nombreAlmacenado;
    private String urlDescarga;
    private String tipoMime;
    private Long tamanioBytes;
    private LocalDateTime fechaSubida;
    private TipoDocumento tipoDocumento;
    private String descripcion;
    private Long expedienteId;
    private Long apadrinadoId;
    private String apadrinadoNombre;
    private Long actividadId;
    private String actividadTitulo;
    private Long subidoPorUsuarioId;
    private String subidoPorNombre;
}
