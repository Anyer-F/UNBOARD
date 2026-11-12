package com.example.backend.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.Entrega;
import com.example.backend.entity.EstadoEntrega;

@Repository
public interface EntregaRepository extends JpaRepository<Entrega, Long> {

    List<Entrega> findByAsignacionIdOrderByVersionDesc(Long asignacionId);

    Optional<Entrega> findFirstByAsignacionIdOrderByVersionDesc(Long asignacionId);

    Optional<Entrega> findFirstByAsignacionIdAndEstadoOrderByVersionDesc(Long asignacionId, EstadoEntrega estado);

    /** true si la actividad tiene al menos una entrega enviada (no borrador). */
    boolean existsByAsignacionActividadIdAndEstadoNot(Long actividadId, EstadoEntrega estado);

    boolean existsByAsignacionActividadId(Long actividadId);

    boolean existsByAsignacionIdAndEstadoNot(Long asignacionId, EstadoEntrega estado);
}
