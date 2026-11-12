package com.example.backend.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.Observacion;

@Repository
public interface ObservacionRepository extends JpaRepository<Observacion, Long> {

    List<Observacion> findByExpedienteIdOrderByFechaDesc(Long expedienteId);

    List<Observacion> findByAsignacionIdOrderByFechaAsc(Long asignacionId);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE Observacion o SET o.asignacion = null WHERE o.asignacion.actividad.id = :actividadId")
    int desvincularActividad(@Param("actividadId") Long actividadId);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE Observacion o SET o.asignacion = null WHERE o.asignacion.id = :asignacionId")
    int desvincularAsignacion(@Param("asignacionId") Long asignacionId);
}
