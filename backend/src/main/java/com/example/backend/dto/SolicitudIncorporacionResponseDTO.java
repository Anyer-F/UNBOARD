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
public class SolicitudIncorporacionResponseDTO {
    private Long id;
    private Long usuarioId;
    private String usuarioNombre;
    private String usuarioCorreo;
    private Long comunidadId;
    private String comunidadNombre;
    private String codigo;
    private String estado;
    private LocalDateTime fechaSolicitud;
    private LocalDateTime fechaRespuesta;
    private String observaciones;
}
