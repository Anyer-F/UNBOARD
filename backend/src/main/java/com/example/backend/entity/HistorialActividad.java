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

/**
 * Registro del historial de cambios: quién hizo qué y cuándo.
 * Cubre actividades, entregas, documentos, expedientes, exportaciones,
 * solicitudes y módulos (ver {@link EntidadHistorial}).
 */
@Entity
@Table(name = "historial_actividad")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HistorialActividad {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    @Builder.Default
    private EntidadHistorial entidad = EntidadHistorial.ACTIVIDAD;

    @Column(name = "id_entidad")
    private Long idEntidad;

    /** Texto de referencia (ej. título de la actividad); se conserva aunque se elimine. */
    @Column(length = 255)
    private String referencia;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_actividad")
    private Actividad actividad;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_asignacion")
    private Asignacion asignacion;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_apadrinado")
    private Apadrinado apadrinado;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_comunidad")
    private Comunidad comunidad;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_anterior", length = 30)
    private EstadoActividad estadoAnterior;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_nuevo", length = 30)
    private EstadoActividad estadoNuevo;

    @Column(nullable = false, length = 60)
    private String accion;

    @Column(columnDefinition = "TEXT")
    private String observaciones;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_usuario")
    private Usuario modificadoPor;

    @Column(name = "fecha_hora", nullable = false)
    private LocalDateTime fechaHora;

    @PrePersist
    public void prePersist() {
        if (this.fechaHora == null) {
            this.fechaHora = LocalDateTime.now();
        }
        if (this.entidad == null) {
            this.entidad = EntidadHistorial.ACTIVIDAD;
        }
    }
}
