package com.example.backend.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.dto.AsignacionResponseDTO;
import com.example.backend.dto.CartaResponseDTO;
import com.example.backend.dto.DocumentoResponseDTO;
import com.example.backend.dto.ExpedienteResponseDTO;
import com.example.backend.dto.HistorialActividadResponseDTO;
import com.example.backend.dto.ObservacionResponseDTO;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Asignacion;
import com.example.backend.entity.EntidadHistorial;
import com.example.backend.entity.EstadoActividad;
import com.example.backend.entity.Expediente;
import com.example.backend.entity.Observacion;
import com.example.backend.entity.TipoDocumento;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.AsignacionRepository;
import com.example.backend.repository.CartaRepository;
import com.example.backend.repository.DocumentoRepository;
import com.example.backend.repository.ExpedienteRepository;
import com.example.backend.repository.ObservacionRepository;

import lombok.RequiredArgsConstructor;

/**
 * Expediente digital del apadrinado. Es gestionado exclusivamente por el
 * coordinador: el apadrinado no tiene ninguna función sobre expedientes.
 */
@Service
@RequiredArgsConstructor
public class ExpedienteService {

    private final ExpedienteRepository expedienteRepository;
    private final AsignacionRepository asignacionRepository;
    private final DocumentoRepository documentoRepository;
    private final CartaRepository cartaRepository;
    private final ObservacionRepository observacionRepository;
    private final SeguridadService seguridadService;
    private final HistorialActividadService historialService;
    private final ConvertidorDTO convertidor;

    /** Expediente del apadrinado; se crea si aún no existe. */
    @Transactional
    public Expediente obtenerOCrear(Apadrinado apadrinado) {
        return expedienteRepository.findByApadrinadoId(apadrinado.getId())
                .orElseGet(() -> expedienteRepository.save(Expediente.builder()
                        .apadrinado(apadrinado)
                        .fechaCreacion(LocalDate.now())
                        .build()));
    }

    @Transactional
    public ExpedienteResponseDTO obtenerPorApadrinado(Long apadrinadoId) {
        Apadrinado apadrinado = seguridadService.verificarApadrinadoDeMiComunidad(apadrinadoId);
        return convertir(obtenerOCrear(apadrinado));
    }

    @Transactional(readOnly = true)
    public ExpedienteResponseDTO obtenerPorId(Long expedienteId) {
        return convertir(seguridadService.verificarExpedienteAccesible(expedienteId));
    }

    /** Resumen de los expedientes de los apadrinados de las comunidades del coordinador. */
    @Transactional(readOnly = true)
    public List<ExpedienteResponseDTO> listarMios() {
        seguridadService.requerirCoordinadorActual();
        var comunidades = seguridadService.comunidadesDelCoordinador();
        return expedienteRepository.findAll().stream()
                .filter(e -> e.getApadrinado() != null && e.getApadrinado().getComunidad() != null
                        && comunidades.contains(e.getApadrinado().getComunidad().getId()))
                .map(e -> ExpedienteResponseDTO.builder()
                        .id(e.getId())
                        .codigo(e.getCodigo())
                        .estado(e.getEstado())
                        .fechaCreacion(e.getFechaCreacion())
                        .apadrinado(convertidor.apadrinado(e.getApadrinado()))
                        .build())
                .collect(Collectors.toList());
    }

    private ExpedienteResponseDTO convertir(Expediente e) {
        Apadrinado apadrinado = e.getApadrinado();
        List<Asignacion> asignaciones = asignacionRepository.findByApadrinadoIdOrderByFechaAsignacionAsc(apadrinado.getId());
        List<AsignacionResponseDTO> actividades = asignaciones.stream()
                .sorted(Comparator.comparing(Asignacion::getFechaAsignacion).reversed())
                .map(s -> convertidor.asignacion(s, true))
                .collect(Collectors.toList());
        List<DocumentoResponseDTO> todos = documentoRepository.findByExpedienteId(e.getId()).stream()
                .sorted(Comparator.comparing(d -> d.getFechaSubida(), Comparator.nullsLast(Comparator.reverseOrder())))
                .map(convertidor::documento)
                .collect(Collectors.toList());
        List<DocumentoResponseDTO> fotos = todos.stream()
                .filter(d -> d.getTipoDocumento() == TipoDocumento.FOTOGRAFIA).collect(Collectors.toList());
        List<DocumentoResponseDTO> documentos = todos.stream()
                .filter(d -> d.getTipoDocumento() != TipoDocumento.FOTOGRAFIA).collect(Collectors.toList());
        List<CartaResponseDTO> cartas = cartaRepository.findByExpedienteId(e.getId()).stream()
                .sorted(Comparator.comparing(c -> c.getFechaCreacion(), Comparator.nullsLast(Comparator.reverseOrder())))
                .map(convertidor::carta)
                .collect(Collectors.toList());
        List<ObservacionResponseDTO> observaciones = observacionRepository.findByExpedienteIdOrderByFechaDesc(e.getId())
                .stream().map(convertidor::observacion).collect(Collectors.toList());
        return ExpedienteResponseDTO.builder()
                .id(e.getId())
                .codigo(e.getCodigo())
                .estado(e.getEstado())
                .fechaCreacion(e.getFechaCreacion())
                .apadrinado(convertidor.apadrinado(apadrinado))
                .actividades(actividades)
                .documentos(documentos)
                .fotografias(fotos)
                .cartas(cartas)
                .observaciones(observaciones)
                .totalActividades(actividades.size())
                .totalAprobadas((int) actividades.stream().filter(s -> s.getEstado() == EstadoActividad.APROBADO).count())
                .totalDocumentos(documentos.size())
                .totalFotografias(fotos.size())
                .totalCartas(cartas.size())
                .build();
    }

    // ==================== OBSERVACIONES ====================

    @Transactional
    public ObservacionResponseDTO agregarObservacion(Long apadrinadoId, String texto, Long asignacionId) {
        if (texto == null || texto.isBlank()) {
            throw new RuntimeException("La observación no puede estar vacía.");
        }
        Apadrinado apadrinado = seguridadService.verificarApadrinadoDeMiComunidad(apadrinadoId);
        Asignacion asignacion = null;
        if (asignacionId != null) {
            asignacion = seguridadService.verificarAsignacionDelCoordinador(asignacionId);
            if (!asignacion.getApadrinado().getId().equals(apadrinadoId)) {
                throw new RuntimeException("La actividad indicada no pertenece al apadrinado.");
            }
        }
        Usuario usuario = seguridadService.usuarioActual();
        Expediente expediente = obtenerOCrear(apadrinado);
        Observacion o = observacionRepository.save(Observacion.builder()
                .expediente(expediente)
                .asignacion(asignacion)
                .texto(texto.trim())
                .autor(usuario)
                .fecha(LocalDateTime.now())
                .build());
        historialService.registrar(EntidadHistorial.OBSERVACION, o.getId(), expediente.getCodigo(), apadrinado,
                null, asignacion != null ? asignacion.getActividad() : null, "OBSERVACIÓN REGISTRADA",
                texto.trim(), usuario);
        return convertidor.observacion(o);
    }

    @Transactional
    public void eliminarObservacion(Long observacionId) {
        Observacion o = observacionRepository.findById(observacionId)
                .orElseThrow(() -> new RuntimeException("Observación no encontrada con ID: " + observacionId));
        Apadrinado apadrinado = seguridadService.verificarApadrinadoDeMiComunidad(o.getExpediente().getApadrinado().getId());
        historialService.registrar(EntidadHistorial.OBSERVACION, o.getId(), o.getExpediente().getCodigo(), apadrinado,
                null, null, "OBSERVACIÓN ELIMINADA", o.getTexto(), seguridadService.usuarioActual());
        observacionRepository.delete(o);
    }

    @Transactional(readOnly = true)
    public List<HistorialActividadResponseDTO> historial(Long apadrinadoId) {
        seguridadService.verificarApadrinadoDeMiComunidad(apadrinadoId);
        return historialService.listarPorApadrinado(apadrinadoId);
    }
}
