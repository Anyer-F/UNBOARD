package com.example.backend.entity;

import java.util.ArrayList;
import java.util.List;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "coordinador")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Coordinador {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_usuario", unique = true)
    private Usuario usuario;

    /**
     * Comunidad principal (compatibilidad con la app móvil).
     */
    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_comunidad")
    private Comunidad comunidad;

    /**
     * FASE F: todas las comunidades bajo la responsabilidad
     * de este coordinador (relación N:M). Un coordinador puede
     * administrar una o varias comunidades.
     */
    @ManyToMany(fetch = FetchType.EAGER, cascade = { CascadeType.PERSIST, CascadeType.MERGE })
    @JoinTable(
            name = "coordinador_comunidad",
            joinColumns = @JoinColumn(name = "id_coordinador"),
            inverseJoinColumns = @JoinColumn(name = "id_comunidad"))
    @Builder.Default
    private List<Comunidad> comunidades = new ArrayList<>();
}
