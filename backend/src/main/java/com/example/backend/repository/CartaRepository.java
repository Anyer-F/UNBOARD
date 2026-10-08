package com.example.backend.repository;

import java.util.List;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.Carta;
import com.example.backend.entity.Carta.EstadoCarta;

@Repository
public interface CartaRepository extends JpaRepository<Carta, Long> {
    List<Carta> findByApadrinadoId(Long apadrinadoId);
    List<Carta> findByExpedienteId(Long expedienteId);
    List<Carta> findByActividadId(Long actividadId);
    List<Carta> findByEstado(EstadoCarta estado);
    List<Carta> findByApadrinadoIdAndEstado(Long apadrinadoId, EstadoCarta estado);

    // Métodos de paginación
    Page<Carta> findByApadrinadoId(Long apadrinadoId, Pageable pageable);
    Page<Carta> findByExpedienteId(Long expedienteId, Pageable pageable);
    Page<Carta> findByActividadId(Long actividadId, Pageable pageable);
    Page<Carta> findByEstado(EstadoCarta estado, Pageable pageable);
    Page<Carta> findByApadrinadoIdAndEstado(Long apadrinadoId, EstadoCarta estado, Pageable pageable);
    Page<Carta> findAll(Pageable pageable);

    // Búsqueda con múltiples filtros
    Page<Carta> findByApadrinadoIdAndEstadoAndTituloContainingIgnoreCase(
            Long apadrinadoId, EstadoCarta estado, String titulo, Pageable pageable);
    Page<Carta> findByExpedienteIdAndEstadoAndTituloContainingIgnoreCase(
            Long expedienteId, EstadoCarta estado, String titulo, Pageable pageable);

    // Cartas de los apadrinados bajo la responsabilidad de un coordinador
    List<Carta> findByApadrinadoCoordinadorId(Long coordinadorId);
    List<Carta> findByApadrinadoCoordinadorIdAndEstado(Long coordinadorId, EstadoCarta estado);
    Page<Carta> findByApadrinadoCoordinadorId(Long coordinadorId, Pageable pageable);
    Page<Carta> findByApadrinadoCoordinadorIdAndEstado(Long coordinadorId, EstadoCarta estado, Pageable pageable);
    Page<Carta> findByApadrinadoCoordinadorIdAndEstadoAndTituloContainingIgnoreCase(
            Long coordinadorId, EstadoCarta estado, String titulo, Pageable pageable);
}
