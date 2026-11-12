package com.example.backend.dto;

import java.time.LocalDateTime;

import com.example.backend.entity.Carta;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CartaResponseDTO {

    private Long id;
    private String titulo;
    private String contenido;
    private LocalDateTime fechaCreacion;
    private LocalDateTime fechaEnvio;
    private Carta.TipoCarta tipoCarta;
    private Carta.EstadoCarta estado;
    private Long expedienteId;
    private Long actividadId;
    private String actividadTitulo;
    private Long entregaId;
    private Integer version;
    private Long apadrinadoId;
    private String apadrinadoNombre;
    private Long escritoPorId;
    private String escritoPorNombre;
}
