package com.example.backend.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.Modulo;

@Repository
public interface ModuloRepository extends JpaRepository<Modulo, Long> {

    List<Modulo> findByComunidadIdOrderByOrdenAscIdAsc(Long comunidadId);

    Optional<Modulo> findFirstByComunidadIdOrderByOrdenAscIdAsc(Long comunidadId);

    long countByComunidadId(Long comunidadId);
}
