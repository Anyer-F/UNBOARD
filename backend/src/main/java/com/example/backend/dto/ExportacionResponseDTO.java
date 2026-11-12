package com.example.backend.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;

import com.example.backend.entity.TipoExportacion;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ExportacionResponseDTO {

    private Long id;
    private TipoExportacion tipo;
    private String nombreArchivo;
    private String tipoMime;
    private Long tamanioBytes;
    private LocalDateTime fechaGeneracion;
    private LocalDateTime fechaExpiracion;
    private Boolean disponible;
    private Long apadrinadoId;
    private String apadrinadoNombre;
    private Long actividadId;
    private String actividadTitulo;
    private LocalDate fechaDesde;
    private LocalDate fechaHasta;
    private String generadoPorNombre;
    private String urlDescarga;
}
