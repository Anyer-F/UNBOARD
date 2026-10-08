package com.example.backend.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.HistorialActividad;

@Repository
public interface HistorialActividadRepository extends JpaRepository<HistorialActividad, Long> {

    List<HistorialActividad> findByActividadIdOrderByFechaHoraDesc(Long actividadId);

    List<HistorialActividad> findByActividadApadrinadoIdOrderByFechaHoraDesc(Long apadrinadoId);

    void deleteByActividadId(Long actividadId);
}
