package com.example.backend.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.Documento;
import com.example.backend.entity.TipoDocumento;

@Repository
public interface DocumentoRepository extends JpaRepository<Documento, Long> {
    List<Documento> findByExpedienteId(Long expedienteId);
    List<Documento> findByExpedienteIdAndTipoDocumento(Long expedienteId, TipoDocumento tipoDocumento);
    List<Documento> findByExpedienteApadrinadoId(Long apadrinadoId);
    List<Documento> findByExpedienteApadrinadoIdAndTipoDocumento(Long apadrinadoId, TipoDocumento tipoDocumento);
    List<Documento> findByActividadId(Long actividadId);
}
