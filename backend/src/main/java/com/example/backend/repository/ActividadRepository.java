package com.example.backend.repository;

import java.util.Collection;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.Actividad;

@Repository
public interface ActividadRepository extends JpaRepository<Actividad, Long> {

    List<Actividad> findByComunidadIdInAndEliminadaFalseOrderByFechaCreacionDesc(Collection<Long> comunidadIds);

    List<Actividad> findByComunidadIdAndEliminadaFalseOrderByFechaCreacionDesc(Long comunidadId);

    List<Actividad> findByModuloIdAndEliminadaFalse(Long moduloId);

    long countByModuloIdAndEliminadaFalse(Long moduloId);

    long countByModuloId(Long moduloId);

    long countByComunidadId(Long comunidadId);

    /** Actividades asignadas a toda la comunidad (para quien se incorpore después). */
    List<Actividad> findByComunidadIdAndAsignadaAComunidadTrueAndEliminadaFalse(Long comunidadId);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("DELETE FROM Actividad a WHERE a.id = :actividadId")
    int eliminarPorId(@Param("actividadId") Long actividadId);
}
