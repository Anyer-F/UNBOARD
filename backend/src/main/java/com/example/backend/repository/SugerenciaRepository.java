package com.example.backend.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.Sugerencia;

@Repository
public interface SugerenciaRepository extends JpaRepository<Sugerencia, Long> {

    List<Sugerencia> findByEntregaIdOrderByFechaAsc(Long entregaId);

    List<Sugerencia> findByEntregaAsignacionIdOrderByFechaAsc(Long asignacionId);
}
