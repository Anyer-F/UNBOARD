package com.example.backend.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.SolicitudIncorporacion;
import com.example.backend.entity.SolicitudIncorporacion.EstadoSolicitud;

@Repository
public interface SolicitudIncorporacionRepository extends JpaRepository<SolicitudIncorporacion, Long> {
    List<SolicitudIncorporacion> findByUsuarioId(Long usuarioId);
    List<SolicitudIncorporacion> findByComunidadId(Long comunidadId);
    List<SolicitudIncorporacion> findByComunidadIdAndEstado(Long comunidadId, EstadoSolicitud estado);
    List<SolicitudIncorporacion> findByUsuarioIdAndEstado(Long usuarioId, EstadoSolicitud estado);
    boolean existsByUsuarioIdAndEstado(Long usuarioId, EstadoSolicitud estado);

    /**
     * FASE F: solicitudes pendientes de varias comunidades
     * (todas las comunidades bajo responsabilidad del coordinador).
     */
    List<SolicitudIncorporacion> findByComunidadIdInAndEstado(List<Long> comunidadIds, EstadoSolicitud estado);
}
