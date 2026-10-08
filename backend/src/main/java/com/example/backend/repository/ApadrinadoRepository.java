package com.example.backend.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.Apadrinado;

@Repository
public interface ApadrinadoRepository extends JpaRepository<Apadrinado, Long> {
    List<Apadrinado> findByCoordinadorId(Long coordinadorId);
    Optional<Apadrinado> findByUsuarioId(Long usuarioId);
    List<Apadrinado> findByComunidadId(Long comunidadId);
    boolean existsByUsuarioId(Long usuarioId);

    /**
     * FASE F: apadrinados accesibles para un coordinador: los que están
     * bajo su responsabilidad directa o pertenecen a cualquiera de
     * sus comunidades (comunidadIds incluye la principal).
     */
    @Query("SELECT DISTINCT a FROM Apadrinado a WHERE a.coordinador.id = :coordinadorId "
            + "OR a.comunidad.id IN :comunidadIds")
    List<Apadrinado> findAccesiblesPorCoordinador(
            @Param("coordinadorId") Long coordinadorId,
            @Param("comunidadIds") List<Long> comunidadIds);

    // Métodos de paginación
    Page<Apadrinado> findByCoordinadorId(Long coordinadorId, Pageable pageable);
    Page<Apadrinado> findByComunidadId(Long comunidadId, Pageable pageable);
    Page<Apadrinado> findAll(Pageable pageable);

    // Búsqueda con múltiples filtros
    Page<Apadrinado> findByCoordinadorIdAndComunidadId(Long coordinadorId, Long comunidadId, Pageable pageable);
    Page<Apadrinado> findByCoordinadorIdAndUsuarioNombreContainingIgnoreCase(Long coordinadorId, String nombre, Pageable pageable);
}
