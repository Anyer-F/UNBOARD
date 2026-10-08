package com.example.backend.entity;

import java.time.LocalDate;

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
@Table(name = "actividad")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Actividad {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String titulo;

    @Column(columnDefinition = "TEXT")
    private String descripcion;

    @Column(name = "fecha_creacion")
    private LocalDate fechaCreacion;

    @Column(name = "fecha_limite")
    private LocalDate fechaLimite;

    @Column(name = "requiere_documento")
    @Builder.Default
    private Boolean requiereDocumento = false;

    @Column(name = "requiere_fotografia")
    @Builder.Default
    private Boolean requiereFotografia = false;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    @Builder.Default
    private EstadoActividad estado = EstadoActividad.PENDIENTE;

    @Column(columnDefinition = "TEXT")
    private String observaciones;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_coordinador")
    private Coordinador coordinador;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_apadrinado")
    private Apadrinado apadrinado;

    @PrePersist
    public void prePersist() {
        if (this.fechaCreacion == null) {
            this.fechaCreacion = LocalDate.now();
        }
        if (this.estado == null) {
            this.estado = EstadoActividad.PENDIENTE;
        }
        if (this.requiereDocumento == null) {
            this.requiereDocumento = false;
        }
        if (this.requiereFotografia == null) {
            this.requiereFotografia = false;
        }
    }
}
