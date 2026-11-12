package com.example.backend.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "comunidad")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Comunidad {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String nombre;

    @Column(length = 150)
    private String municipio;

    @Column(length = 150)
    private String departamento;

    /** Cómo se incorporan los apadrinados con el código de la comunidad. */
    @Enumerated(EnumType.STRING)
    @Column(name = "modo_incorporacion", nullable = false, length = 20)
    @Builder.Default
    private ModoIncorporacion modoIncorporacion = ModoIncorporacion.SOLICITUD;
}
