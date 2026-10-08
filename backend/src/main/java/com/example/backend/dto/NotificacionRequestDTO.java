package com.example.backend.dto;

import com.example.backend.entity.TipoNotificacion;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NotificacionRequestDTO {
    private String titulo;
    private String mensaje;
    private TipoNotificacion tipo;
    private Long usuarioId;
    private Long idReferencia;
    private String tipoReferencia;
}
