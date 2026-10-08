package com.example.backend.entity;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "carta")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Carta {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 200)
    private String titulo;

    @Column(columnDefinition = "TEXT", nullable = false)
    private String contenido;

    @Column(name = "fecha_creacion")
    private LocalDateTime fechaCreacion;

    @Column(name = "fecha_envio")
    private LocalDateTime fechaEnvio;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo_carta", nullable = false, length = 50)
    @Builder.Default
    private TipoCarta tipoCarta = TipoCarta.GENERAL;

    @Column(name = "estado", nullable = false, length = 30)
    @Builder.Default
    private EstadoCarta estado = EstadoCarta.BORRADOR;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_expediente", nullable = false)
    private Expediente expediente;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_actividad")
    private Actividad actividad;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_apadrinado", nullable = false)
    private Apadrinado apadrinado;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_usuario", nullable = false)
    private Usuario escritoPor;

    @Column(columnDefinition = "TEXT")
    private String observaciones;

    @PrePersist
    public void prePersist() {
        if (this.fechaCreacion == null) {
            this.fechaCreacion = LocalDateTime.now();
        }
        if (this.tipoCarta == null) {
            this.tipoCarta = TipoCarta.GENERAL;
        }
        if (this.estado == null) {
            this.estado = EstadoCarta.BORRADOR;
        }
    }

    public enum TipoCarta {
        GENERAL,
        CARTA_PADRINO,
        CARTA_APADRINADO,
        CUMPLEAÑOS,
        GRACIAS,
        NAVIDAD,
        PERSONAL
    }

    public enum EstadoCarta {
        BORRADOR,
        ENVIADA,
        RECIBIDA,
        APROBADA,
        RECHAZADA
    }
}
