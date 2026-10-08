package com.example.backend.dto;

import java.time.LocalDateTime;

import com.example.backend.entity.TipoNotificacion;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NotificacionResponseDTO {
    private Long id;
    private String titulo;
    private String mensaje;
    private TipoNotificacion tipo;
    private LocalDateTime fechaCreacion;
    private Boolean leida;
    private Long idReferencia;
    private String tipoReferencia;
    private Long usuarioId;
    private String usuarioNombre;
}
