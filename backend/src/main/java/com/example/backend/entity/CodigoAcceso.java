package com.example.backend.entity;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Código de acceso generado por un coordinador para que
 * nuevos apadrinados puedan solicitar incorporarse a su comunidad.
 */
@Entity
@Table(name = "codigo_acceso")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CodigoAcceso {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 20, unique = true)
    private String codigo;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_comunidad", nullable = false)
    private Comunidad comunidad;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_coordinador", nullable = false)
    private Coordinador coordinador;

    @Column(nullable = false)
    private Boolean activo;

    @Column(name = "fecha_creacion", nullable = false)
    private LocalDateTime fechaCreacion;

    @Column(name = "fecha_expiracion")
    private LocalDateTime fechaExpiracion;

    @Column(name = "max_usos")
    private Integer maxUsos;

    @Column(nullable = false)
    private Integer usos;

    @Column(length = 255)
    private String descripcion;
}
