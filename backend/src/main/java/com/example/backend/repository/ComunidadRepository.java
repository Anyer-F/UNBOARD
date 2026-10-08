package com.example.backend.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.Comunidad;

@Repository
public interface ComunidadRepository extends JpaRepository<Comunidad, Long> {
    List<Comunidad> findByMunicipioIgnoreCase(String municipio);
    List<Comunidad> findByDepartamentoIgnoreCase(String departamento);
    boolean existsByNombreIgnoreCase(String nombre);
}
