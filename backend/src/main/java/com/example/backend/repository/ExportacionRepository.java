package com.example.backend.repository;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.Exportacion;

@Repository
public interface ExportacionRepository extends JpaRepository<Exportacion, Long> {

    List<Exportacion> findByGeneradoPorIdOrderByFechaGeneracionDesc(Long usuarioId);

    List<Exportacion> findByDisponibleTrueAndFechaExpiracionBefore(LocalDateTime fecha);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE Exportacion e SET e.actividad = null WHERE e.actividad.id = :actividadId")
    int desvincularActividad(@Param("actividadId") Long actividadId);
}
