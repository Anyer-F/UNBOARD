package com.example.backend.dto;

import com.example.backend.entity.EstadoActividad;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ActividadEstadoDTO {
    private EstadoActividad estado;
    private String observaciones;
}
