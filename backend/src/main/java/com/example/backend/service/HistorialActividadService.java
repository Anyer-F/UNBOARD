package com.example.backend.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.dto.HistorialActividadResponseDTO;
import com.example.backend.entity.Actividad;
import com.example.backend.entity.EstadoActividad;
import com.example.backend.entity.HistorialActividad;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.HistorialActividadRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class HistorialActividadService {

    private final HistorialActividadRepository historialActividadRepository;

    @Transactional
    public HistorialActividad registrarCambio(
            Actividad actividad,
            EstadoActividad estadoAnterior,
            EstadoActividad estadoNuevo,
            String accion,
            String observaciones,
            Usuario modificadoPor) {

        HistorialActividad historial = HistorialActividad.builder()
                .actividad(actividad)
                .estadoAnterior(estadoAnterior)
                .estadoNuevo(estadoNuevo)
                .accion(accion)
                .observaciones(observaciones)
                .modificadoPor(modificadoPor)
                .fechaHora(LocalDateTime.now())
                .build();

        HistorialActividad guardado = historialActividadRepository.save(historial);
        log.info("Historial registrado: Actividad ID {} | Acción: {} | {} -> {}",
                actividad.getId(), accion, estadoAnterior, estadoNuevo);
        return guardado;
    }

    @Transactional(readOnly = true)
    public List<HistorialActividadResponseDTO> listarPorActividad(Long actividadId) {
        return historialActividadRepository.findByActividadIdOrderByFechaHoraDesc(actividadId)
                .stream()
                .map(this::convertirAResponseDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<HistorialActividadResponseDTO> listarPorApadrinado(Long apadrinadoId) {
        return historialActividadRepository.findByActividadApadrinadoIdOrderByFechaHoraDesc(apadrinadoId)
                .stream()
                .map(this::convertirAResponseDTO)
                .collect(Collectors.toList());
    }

    public HistorialActividadResponseDTO convertirAResponseDTO(HistorialActividad h) {
        Long usuarioId = null;
        String usuarioNombre = null;
        String usuarioRol = null;

        if (h.getModificadoPor() != null) {
            usuarioId = h.getModificadoPor().getId();
            usuarioNombre = h.getModificadoPor().getNombre();
            if (h.getModificadoPor().getRol() != null) {
                usuarioRol = h.getModificadoPor().getRol().getNombre();
            }
        }

        String titulo = null;
        Long actId = null;
        if (h.getActividad() != null) {
            actId = h.getActividad().getId();
            titulo = h.getActividad().getTitulo();
        }

        return HistorialActividadResponseDTO.builder()
                .id(h.getId())
                .actividadId(actId)
                .actividadTitulo(titulo)
                .estadoAnterior(h.getEstadoAnterior())
                .estadoNuevo(h.getEstadoNuevo())
                .accion(h.getAccion())
                .observaciones(h.getObservaciones())
                .modificadoPorUsuarioId(usuarioId)
                .modificadoPorNombre(usuarioNombre)
                .modificadoPorRol(usuarioRol)
                .fechaHora(h.getFechaHora())
                .build();
    }
}
