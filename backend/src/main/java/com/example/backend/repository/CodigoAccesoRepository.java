package com.example.backend.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.CodigoAcceso;

@Repository
public interface CodigoAccesoRepository extends JpaRepository<CodigoAcceso, Long> {
    Optional<CodigoAcceso> findByCodigo(String codigo);
    List<CodigoAcceso> findByComunidadId(Long comunidadId);
    List<CodigoAcceso> findByCoordinadorId(Long coordinadorId);
    List<CodigoAcceso> findByComunidadIdAndActivoTrue(Long comunidadId);
}
