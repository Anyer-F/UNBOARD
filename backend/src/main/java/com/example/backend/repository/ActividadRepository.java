package com.example.backend.repository;

import java.util.List;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.Actividad;
import com.example.backend.entity.EstadoActividad;

@Repository
public interface ActividadRepository extends JpaRepository<Actividad, Long> {
    List<Actividad> findByApadrinadoId(Long apadrinadoId);
    List<Actividad> findByApadrinadoIdAndEstado(Long apadrinadoId, EstadoActividad estado);
    List<Actividad> findByCoordinadorId(Long coordinadorId);
    List<Actividad> findByCoordinadorIdAndEstado(Long coordinadorId, EstadoActividad estado);
    List<Actividad> findByCoordinadorIdAndEstadoIn(Long coordinadorId, List<EstadoActividad> estados);
    List<Actividad> findByEstadoIn(List<EstadoActividad> estados);

    // Métodos de paginación
    Page<Actividad> findByApadrinadoId(Long apadrinadoId, Pageable pageable);
    Page<Actividad> findByApadrinadoIdAndEstado(Long apadrinadoId, EstadoActividad estado, Pageable pageable);
    Page<Actividad> findByCoordinadorId(Long coordinadorId, Pageable pageable);
    Page<Actividad> findByCoordinadorIdAndEstado(Long coordinadorId, EstadoActividad estado, Pageable pageable);
    Page<Actividad> findByEstado(EstadoActividad estado, Pageable pageable);
    Page<Actividad> findAll(Pageable pageable);

    // Búsqueda con múltiples filtros
    Page<Actividad> findByApadrinadoIdAndEstadoAndTituloContainingIgnoreCase(
            Long apadrinadoId, EstadoActividad estado, String titulo, Pageable pageable);
    Page<Actividad> findByCoordinadorIdAndEstadoAndTituloContainingIgnoreCase(
            Long coordinadorId, EstadoActividad estado, String titulo, Pageable pageable);
}
