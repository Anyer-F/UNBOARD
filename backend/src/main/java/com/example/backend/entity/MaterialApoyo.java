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
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Material de apoyo compartido por el coordinador
 * con los apadrinados de su comunidad.
 */
@Entity
@Table(name = "material_apoyo")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MaterialApoyo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 255)
    private String titulo;

    @Column(columnDefinition = "TEXT")
    private String descripcion;

    @Column(name = "nombre_original", nullable = false, length = 255)
    private String nombreOriginal;

    @Column(name = "nombre_almacenado", nullable = false, length = 255, unique = true)
    private String nombreAlmacenado;

    @Column(name = "ruta_archivo", nullable = false, length = 500)
    private String rutaArchivo;

    @Column(name = "tipo_mime", length = 100)
    private String tipoMime;

    @Column(name = "tamanio_bytes")
    private Long tamanioBytes;

    @Column(name = "fecha_subida")
    private LocalDateTime fechaSubida;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_comunidad", nullable = false)
    private Comunidad comunidad;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_coordinador", nullable = false)
    private Coordinador coordinador;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_usuario")
    private Usuario subidoPor;

    @PrePersist
    public void prePersist() {
        if (this.fechaSubida == null) {
            this.fechaSubida = LocalDateTime.now();
        }
    }
}
