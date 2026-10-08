package com.example.backend.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.Coordinador;

@Repository
public interface CoordinadorRepository extends JpaRepository<Coordinador, Long> {
    Optional<Coordinador> findByUsuarioId(Long usuarioId);
    boolean existsByUsuarioId(Long usuarioId);
    java.util.List<Coordinador> findByComunidadId(Long comunidadId);

    /**
     * FASE F: coordinadores que tienen la comunidad indicada
     * entre sus comunidades asociadas (tabla coordinador_comunidad).
     */
    @Query("SELECT c FROM Coordinador c JOIN c.comunidades cm WHERE cm.id = :comunidadId")
    List<Coordinador> findByComunidadAsociadaId(@Param("comunidadId") Long comunidadId);
}
