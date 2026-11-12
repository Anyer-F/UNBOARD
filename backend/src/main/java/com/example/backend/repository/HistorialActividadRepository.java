package com.example.backend.repository;

import java.util.Collection;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.HistorialActividad;

@Repository
public interface HistorialActividadRepository extends JpaRepository<HistorialActividad, Long> {

    List<HistorialActividad> findByActividadIdOrderByFechaHoraDesc(Long actividadId);

    List<HistorialActividad> findByAsignacionIdOrderByFechaHoraDesc(Long asignacionId);

    List<HistorialActividad> findByApadrinadoIdOrderByFechaHoraDesc(Long apadrinadoId);

    List<HistorialActividad> findTop200ByComunidadIdInOrderByFechaHoraDesc(Collection<Long> comunidadIds);

    List<HistorialActividad> findTop200ByComunidadIdOrderByFechaHoraDesc(Long comunidadId);

    /** El historial se conserva al eliminar definitivamente una actividad. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE HistorialActividad h SET h.actividad = null, h.asignacion = null WHERE h.actividad.id = :actividadId")
    int desvincularActividad(@Param("actividadId") Long actividadId);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE HistorialActividad h SET h.asignacion = null WHERE h.asignacion.id = :asignacionId")
    int desvincularAsignacion(@Param("asignacionId") Long asignacionId);
}
