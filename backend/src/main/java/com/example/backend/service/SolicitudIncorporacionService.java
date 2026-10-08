package com.example.backend.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.config.AccesoDenegadoException;
import com.example.backend.dto.SolicitudIncorporacionRequestDTO;
import com.example.backend.dto.SolicitudIncorporacionResponseDTO;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.CodigoAcceso;
import com.example.backend.entity.Comunidad;
import com.example.backend.entity.Coordinador;
import com.example.backend.entity.Expediente;
import com.example.backend.entity.SolicitudIncorporacion;
import com.example.backend.entity.SolicitudIncorporacion.EstadoSolicitud;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.CodigoAccesoRepository;
import com.example.backend.repository.ComunidadRepository;
import com.example.backend.repository.ExpedienteRepository;
import com.example.backend.repository.SolicitudIncorporacionRepository;

import lombok.RequiredArgsConstructor;

/**
 * Servicio de solicitudes de incorporación a comunidades.
 *
 * Flujo: un usuario con rol Apadrinado (sin comunidad asignada)
 * solicita unirse a una comunidad con un código de acceso válido;
 * el coordinador responsable de esa comunidad aprueba o rechaza.
 * Al aprobarse, se crea el perfil de apadrinado en la comunidad
 * bajo la responsabilidad del coordinador que aprueba.
 */
@Service
@RequiredArgsConstructor
public class SolicitudIncorporacionService {

    private final SolicitudIncorporacionRepository solicitudRepository;
    private final CodigoAccesoService codigoAccesoService;
    private final CodigoAccesoRepository codigoAccesoRepository;
    private final ComunidadRepository comunidadRepository;
    private final ApadrinadoRepository apadrinadoRepository;
    private final ExpedienteRepository expedienteRepository;
    private final SeguridadService seguridadService;

    @Transactional
    public SolicitudIncorporacionResponseDTO solicitar(SolicitudIncorporacionRequestDTO request) {
        Usuario usuario = seguridadService.usuarioActual();

        // Solo usuarios con rol Apadrinado pueden solicitar incorporación
        if (!seguridadService.esApadrinado(usuario)) {
            throw new AccesoDenegadoException(
                    "Solo los usuarios con rol Apadrinado pueden solicitar incorporación.");
        }

        // Un apadrinado con comunidad asignada no puede cambiarse libremente
        if (apadrinadoRepository.existsByUsuarioId(usuario.getId())) {
            throw new AccesoDenegadoException(
                    "Usted ya pertenece a una comunidad.");
        }

        Comunidad comunidad = comunidadRepository.findById(request.getComunidadId())
                .orElseThrow(() -> new RuntimeException(
                        "Comunidad no encontrada con ID: " + request.getComunidadId()));

        // Validar el código de acceso de la comunidad
        CodigoAcceso codigo = codigoAccesoService.validarCodigo(
                comunidad.getId(), request.getCodigo());

        // Evitar solicitudes pendientes duplicadas
        if (solicitudRepository.existsByUsuarioIdAndEstado(usuario.getId(), EstadoSolicitud.PENDIENTE)) {
            throw new RuntimeException("Ya tiene una solicitud de incorporación pendiente.");
        }

        SolicitudIncorporacion solicitud = SolicitudIncorporacion.builder()
                .usuario(usuario)
                .comunidad(comunidad)
                .codigo(codigo.getCodigo())
                .estado(EstadoSolicitud.PENDIENTE)
                .fechaSolicitud(LocalDateTime.now())
                .build();

        solicitudRepository.save(solicitud);
        return convertirAResponseDTO(solicitud);
    }

    @Transactional(readOnly = true)
    public List<SolicitudIncorporacionResponseDTO> listarMias() {
        Usuario usuario = seguridadService.usuarioActual();
        return solicitudRepository.findByUsuarioId(usuario.getId()).stream()
                .map(this::convertirAResponseDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<SolicitudIncorporacionResponseDTO> listarPendientes() {
        seguridadService.requerirCoordinador();
        // FASE F: solicitudes pendientes de TODAS las comunidades
        // bajo la responsabilidad del coordinador
        Set<Long> idsComunidades = seguridadService.comunidadesDelCoordinador();
        if (idsComunidades.isEmpty()) {
            throw new AccesoDenegadoException("No tiene comunidades asignadas.");
        }
        return solicitudRepository.findByComunidadIdInAndEstado(
                new ArrayList<>(idsComunidades), EstadoSolicitud.PENDIENTE).stream()
                .map(this::convertirAResponseDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public SolicitudIncorporacionResponseDTO aprobar(Long id) {
        seguridadService.requerirCoordinador();
        Coordinador coordinador = seguridadService.coordinadorActual();
        SolicitudIncorporacion solicitud = cargarPendienteDeMiComunidad(id);

        // Crear el perfil de apadrinado en la comunidad, bajo este coordinador
        Apadrinado apadrinado = Apadrinado.builder()
                .usuario(solicitud.getUsuario())
                .coordinador(coordinador)
                .comunidad(solicitud.getComunidad())
                .build();
        apadrinadoRepository.save(apadrinado);

        // Regla de negocio: expediente digital único por apadrinado
        if (!expedienteRepository.existsByApadrinadoId(apadrinado.getId())) {
            expedienteRepository.save(Expediente.builder()
                    .apadrinado(apadrinado)
                    .fechaCreacion(LocalDate.now())
                    .build());
        }

        // Registrar el uso del código de acceso
        codigoAccesoRepository.findByCodigo(solicitud.getCodigo())
                .ifPresent(codigoAccesoService::registrarUso);

        solicitud.setEstado(EstadoSolicitud.APROBADA);
        solicitud.setFechaRespuesta(LocalDateTime.now());
        solicitud.setCoordinador(coordinador);
        solicitudRepository.save(solicitud);
        return convertirAResponseDTO(solicitud);
    }

    @Transactional
    public SolicitudIncorporacionResponseDTO rechazar(Long id, String observaciones) {
        seguridadService.requerirCoordinador();
        Coordinador coordinador = seguridadService.coordinadorActual();
        SolicitudIncorporacion solicitud = cargarPendienteDeMiComunidad(id);

        solicitud.setEstado(EstadoSolicitud.RECHAZADA);
        solicitud.setFechaRespuesta(LocalDateTime.now());
        solicitud.setCoordinador(coordinador);
        solicitud.setObservaciones(observaciones);
        solicitudRepository.save(solicitud);
        return convertirAResponseDTO(solicitud);
    }

    private SolicitudIncorporacion cargarPendienteDeMiComunidad(Long id) {
        SolicitudIncorporacion solicitud = solicitudRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Solicitud no encontrada con ID: " + id));
        if (solicitud.getEstado() != EstadoSolicitud.PENDIENTE) {
            throw new RuntimeException("La solicitud ya fue resuelta.");
        }
        // FASE F: la solicitud puede pertenecer a cualquiera de sus comunidades
        if (solicitud.getComunidad() == null
                || !seguridadService.comunidadesDelCoordinador()
                        .contains(solicitud.getComunidad().getId())) {
            throw new AccesoDenegadoException("La solicitud no pertenece a su comunidad.");
        }
        return solicitud;
    }

    private SolicitudIncorporacionResponseDTO convertirAResponseDTO(SolicitudIncorporacion solicitud) {
        return SolicitudIncorporacionResponseDTO.builder()
                .id(solicitud.getId())
                .usuarioId(solicitud.getUsuario().getId())
                .usuarioNombre(solicitud.getUsuario().getNombre())
                .usuarioCorreo(solicitud.getUsuario().getCorreo())
                .comunidadId(solicitud.getComunidad().getId())
                .comunidadNombre(solicitud.getComunidad().getNombre())
                .codigo(solicitud.getCodigo())
                .estado(solicitud.getEstado().name())
                .fechaSolicitud(solicitud.getFechaSolicitud())
                .fechaRespuesta(solicitud.getFechaRespuesta())
                .observaciones(solicitud.getObservaciones())
                .build();
    }
}
