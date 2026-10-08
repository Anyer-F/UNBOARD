package com.example.backend.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.MaterialApoyo;

@Repository
public interface MaterialApoyoRepository extends JpaRepository<MaterialApoyo, Long> {
    List<MaterialApoyo> findByComunidadIdOrderByFechaSubidaDesc(Long comunidadId);
    List<MaterialApoyo> findByCoordinadorIdOrderByFechaSubidaDesc(Long coordinadorId);

    /**
     * FASE F: material de varias comunidades a la vez
     * (todas las comunidades bajo responsabilidad del coordinador).
     */
    List<MaterialApoyo> findByComunidadIdInOrderByFechaSubidaDesc(List<Long> comunidadIds);
}
