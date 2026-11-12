package com.example.backend.service;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.dto.HistorialActividadResponseDTO;
import com.example.backend.entity.Actividad;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Asignacion;
import com.example.backend.entity.Comunidad;
import com.example.backend.entity.EntidadHistorial;
import com.example.backend.entity.EstadoActividad;
import com.example.backend.entity.HistorialActividad;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.HistorialActividadRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Historial y trazabilidad: registra qué usuario realizó cada acción y cuándo.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class HistorialActividadService {

    private final HistorialActividadRepository historialActividadRepository;
    private final ConvertidorDTO convertidor;

    /** Acción sobre una actividad (creación, edición, eliminación, adjuntos...). */
    @Transactional
    public HistorialActividad registrarActividad(Actividad actividad, String accion, String detalle, Usuario usuario) {
        return guardar(HistorialActividad.builder()
                .entidad(EntidadHistorial.ACTIVIDAD)
                .idEntidad(actividad.getId())
                .referencia(actividad.getTitulo())
                .actividad(actividad)
                .comunidad(actividad.getComunidad())
                .accion(accion)
                .observaciones(detalle)
                .modificadoPor(usuario));
    }

    /** Cambio en la asignación de un apadrinado (estado, entrega, revisión...). */
    @Transactional
    public HistorialActividad registrarAsignacion(
            Asignacion asignacion,
            EntidadHistorial entidad,
            Long idEntidad,
            EstadoActividad estadoAnterior,
            EstadoActividad estadoNuevo,
            String accion,
            String detalle,
            Usuario usuario) {
        Actividad actividad = asignacion.getActividad();
        return guardar(HistorialActividad.builder()
                .entidad(entidad != null ? entidad : EntidadHistorial.ASIGNACION)
                .idEntidad(idEntidad != null ? idEntidad : asignacion.getId())
                .referencia(actividad != null ? actividad.getTitulo() : null)
                .actividad(actividad)
                .asignacion(asignacion)
                .apadrinado(asignacion.getApadrinado())
                .comunidad(actividad != null ? actividad.getComunidad() : null)
                .estadoAnterior(estadoAnterior)
                .estadoNuevo(estadoNuevo)
                .accion(accion)
                .observaciones(detalle)
                .modificadoPor(usuario));
    }

    /** Registro genérico (expediente, exportación, solicitud, módulo...). */
    @Transactional
    public HistorialActividad registrar(
            EntidadHistorial entidad,
            Long idEntidad,
            String referencia,
            Apadrinado apadrinado,
            Comunidad comunidad,
            Actividad actividad,
            String accion,
            String detalle,
            Usuario usuario) {
        return guardar(HistorialActividad.builder()
                .entidad(entidad)
                .idEntidad(idEntidad)
                .referencia(referencia)
                .apadrinado(apadrinado)
                .comunidad(comunidad != null ? comunidad
                        : apadrinado != null ? apadrinado.getComunidad()
                        : actividad != null ? actividad.getComunidad() : null)
                .actividad(actividad)
                .accion(accion)
                .observaciones(detalle)
                .modificadoPor(usuario));
    }

    private HistorialActividad guardar(HistorialActividad.HistorialActividadBuilder builder) {
        HistorialActividad h = historialActividadRepository.save(builder.fechaHora(LocalDateTime.now()).build());
        log.info("Historial: {} {} | {} | {}", h.getEntidad(), h.getIdEntidad(), h.getAccion(), h.getReferencia());
        return h;
    }

    // ==================== CONSULTAS ====================

    @Transactional(readOnly = true)
    public List<HistorialActividadResponseDTO> listarPorActividad(Long actividadId) {
        return convertir(historialActividadRepository.findByActividadIdOrderByFechaHoraDesc(actividadId));
    }

    @Transactional(readOnly = true)
    public List<HistorialActividadResponseDTO> listarPorAsignacion(Long asignacionId) {
        return convertir(historialActividadRepository.findByAsignacionIdOrderByFechaHoraDesc(asignacionId));
    }

    @Transactional(readOnly = true)
    public List<HistorialActividadResponseDTO> listarPorApadrinado(Long apadrinadoId) {
        return convertir(historialActividadRepository.findByApadrinadoIdOrderByFechaHoraDesc(apadrinadoId));
    }

    @Transactional(readOnly = true)
    public List<HistorialActividadResponseDTO> listarPorComunidades(Collection<Long> comunidadIds) {
        if (comunidadIds.isEmpty()) {
            return List.of();
        }
        return convertir(historialActividadRepository.findTop200ByComunidadIdInOrderByFechaHoraDesc(comunidadIds));
    }

    private List<HistorialActividadResponseDTO> convertir(List<HistorialActividad> lista) {
        return lista.stream().map(convertidor::historial).collect(Collectors.toList());
    }
}
