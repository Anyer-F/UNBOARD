package com.example.backend.entity;

import java.time.LocalDate;
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
 * Actividad creada por el coordinador dentro de un módulo de una comunidad.
 * Es compartida por todos los apadrinados asignados; el estado de cada
 * apadrinado se lleva en {@link Asignacion}.
 */
@Entity
@Table(name = "actividad")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Actividad {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private TipoActividad tipo = TipoActividad.TAREA;

    @Column(nullable = false, length = 150)
    private String titulo;

    @Column(columnDefinition = "TEXT")
    private String descripcion;

    @Column(columnDefinition = "TEXT")
    private String instrucciones;

    @Column(name = "fecha_creacion")
    private LocalDateTime fechaCreacion;

    @Column(name = "fecha_actualizacion")
    private LocalDateTime fechaActualizacion;

    /** Solo para tareas. */
    @Column(name = "fecha_limite")
    private LocalDate fechaLimite;

    @Column(name = "requiere_documento")
    @Builder.Default
    private Boolean requiereDocumento = false;

    @Column(name = "requiere_fotografia")
    @Builder.Default
    private Boolean requiereFotografia = false;

    @Column(name = "requiere_carta")
    @Builder.Default
    private Boolean requiereCarta = false;

    /** Otros contenidos requeridos (texto libre), solo para tareas. */
    @Column(name = "otros_requisitos", columnDefinition = "TEXT")
    private String otrosRequisitos;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_comunidad")
    private Comunidad comunidad;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_modulo")
    private Modulo modulo;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_coordinador")
    private Coordinador coordinador;

    /**
     * true: asignada a toda la comunidad (también la reciben los
     * apadrinados que se incorporen después); false: a los seleccionados.
     */
    @Column(name = "asignada_a_comunidad", nullable = false)
    @Builder.Default
    private Boolean asignadaAComunidad = false;

    /** Eliminación lógica: la actividad tenía entregas. */
    @Column(nullable = false)
    @Builder.Default
    private Boolean eliminada = false;

    @Column(name = "fecha_eliminacion")
    private LocalDateTime fechaEliminacion;

    @PrePersist
    public void prePersist() {
        if (this.fechaCreacion == null) {
            this.fechaCreacion = LocalDateTime.now();
        }
        if (this.tipo == null) {
            this.tipo = TipoActividad.TAREA;
        }
        if (this.requiereDocumento == null) {
            this.requiereDocumento = false;
        }
        if (this.requiereFotografia == null) {
            this.requiereFotografia = false;
        }
        if (this.requiereCarta == null) {
            this.requiereCarta = false;
        }
        if (this.asignadaAComunidad == null) {
            this.asignadaAComunidad = false;
        }
        if (this.eliminada == null) {
            this.eliminada = false;
        }
    }

    public boolean esTarea() {
        return this.tipo == TipoActividad.TAREA;
    }
}
