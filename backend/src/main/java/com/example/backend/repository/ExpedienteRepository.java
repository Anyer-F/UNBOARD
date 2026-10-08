package com.example.backend.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.EstadoExpediente;
import com.example.backend.entity.Expediente;

@Repository
public interface ExpedienteRepository extends JpaRepository<Expediente, Long> {
    Optional<Expediente> findByApadrinadoId(Long apadrinadoId);
    List<Expediente> findByEstado(EstadoExpediente estado);
    boolean existsByApadrinadoId(Long apadrinadoId);

    // Métodos de paginación
    Page<Expediente> findByApadrinadoId(Long apadrinadoId, Pageable pageable);
    Page<Expediente> findByEstado(EstadoExpediente estado, Pageable pageable);
    Page<Expediente> findAll(Pageable pageable);

    // Búsqueda con múltiples filtros
    Page<Expediente> findByEstadoAndCodigoContainingIgnoreCase(EstadoExpediente estado, String codigo, Pageable pageable);

    // Expedientes de los apadrinados bajo la responsabilidad de un coordinador
    List<Expediente> findByApadrinadoCoordinadorId(Long coordinadorId);
}
