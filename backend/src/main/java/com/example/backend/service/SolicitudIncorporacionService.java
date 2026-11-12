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
import com.example.backend.entity.EntidadHistorial;
import com.example.backend.entity.Expediente;
import com.example.backend.entity.ModoIncorporacion;
import com.example.backend.entity.SolicitudIncorporacion;
import com.example.backend.entity.SolicitudIncorporacion.EstadoSolicitud;
import com.example.backend.entity.TipoNotificacion;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.CodigoAccesoRepository;
import com.example.backend.repository.CoordinadorRepository;
import com.example.backend.repository.ExpedienteRepository;
import com.example.backend.repository.SolicitudIncorporacionRepository;

import lombok.RequiredArgsConstructor;

/**
 * Incorporación a comunidades mediante el código de acceso.
 *
 * Según la configuración de la comunidad:
 * - SOLICITUD: se crea una solicitud que el coordinador revisa (puede
 *   consultar el perfil del solicitante) y acepta o rechaza.
 * - DIRECTO: el código válido incorpora al apadrinado de inmediato.
 *
 * Un apadrinado que ya pertenece a una comunidad no puede cambiarse
 * libremente a otra.
 */
@Service
@RequiredArgsConstructor
public class SolicitudIncorporacionService {

    private final SolicitudIncorporacionRepository solicitudRepository;
    private final CodigoAccesoService codigoAccesoService;
    private final CodigoAccesoRepository codigoAccesoRepository;
    private final ApadrinadoRepository apadrinadoRepository;
    private final CoordinadorRepository coordinadorRepository;
    private final ExpedienteRepository expedienteRepository;
    private final SeguridadService seguridadService;
    private final ActividadService actividadService;
    private final NotificacionService notificacionService;
    private final HistorialActividadService historialService;

    @Transactional
    public SolicitudIncorporacionResponseDTO solicitar(SolicitudIncorporacionRequestDTO request) {
        Usuario usuario = seguridadService.usuarioActual();
        if (!seguridadService.esApadrinado(usuario)) {
            throw new AccesoDenegadoException(
                    "Solo los usuarios con rol Apadrinado pueden solicitar incorporación.");
        }
        if (apadrinadoRepository.existsByUsuarioId(usuario.getId())) {
            throw new AccesoDenegadoException(
                    "Usted ya pertenece a una comunidad. Para cambiar de comunidad hable con su coordinador.");
        }
        if (request.getCodigo() == null || request.getCodigo().isBlank()) {
            throw new RuntimeException("El código de acceso es obligatorio.");
        }
        CodigoAcceso porTexto = codigoAccesoRepository.findByCodigo(request.getCodigo().trim().toUpperCase())
                .orElseThrow(() -> new RuntimeException("Código de acceso inválido."));
        Long comunidadId = request.getComunidadId() != null ? request.getComunidadId() : porTexto.getComunidad().getId();
        CodigoAcceso codigo = codigoAccesoService.validarCodigo(comunidadId, request.getCodigo());
        Comunidad comunidad = codigo.getComunidad();

        if (solicitudRepository.existsByUsuarioIdAndEstado(usuario.getId(), EstadoSolicitud.PENDIENTE)) {
            throw new RuntimeException("Ya tiene una solicitud de incorporación pendiente.");
        }

        SolicitudIncorporacion solicitud = solicitudRepository.save(SolicitudIncorporacion.builder()
                .usuario(usuario)
                .comunidad(comunidad)
                .codigo(codigo.getCodigo())
                .estado(EstadoSolicitud.PENDIENTE)
                .fechaSolicitud(LocalDateTime.now())
                .build());
        historialService.registrar(EntidadHistorial.SOLICITUD, solicitud.getId(), ConvertidorDTO.nombreCompleto(usuario),
                null, comunidad, null, "SOLICITUD DE INCORPORACIÓN", "Código " + codigo.getCodigo(), usuario);

        Coordinador responsable = codigo.getCoordinador() != null ? codigo.getCoordinador() : responsableDe(comunidad);
        if (comunidad.getModoIncorporacion() == ModoIncorporacion.DIRECTO && responsable != null) {
            // Ingreso directo controlado por el código
            incorporar(solicitud, responsable, responsable.getUsuario(), "Ingreso directo con código");
        } else if (responsable != null) {
            notificacionService.notificar(responsable.getUsuario(), "Nueva solicitud de incorporación",
                    ConvertidorDTO.nombreCompleto(usuario) + " solicita unirse a " + comunidad.getNombre() + ".",
                    TipoNotificacion.NUEVA_SOLICITUD, solicitud.getId(), "SOLICITUD");
        }
        return convertir(solicitud);
    }

    @Transactional(readOnly = true)
    public List<SolicitudIncorporacionResponseDTO> listarMias() {
        Usuario usuario = seguridadService.usuarioActual();
        return solicitudRepository.findByUsuarioId(usuario.getId()).stream()
                .sorted((a, b) -> b.getFechaSolicitud().compareTo(a.getFechaSolicitud()))
                .map(this::convertir)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<SolicitudIncorporacionResponseDTO> listarPendientes(Long comunidadId) {
        seguridadService.requerirCoordinador();
        Set<Long> ids = seguridadService.comunidadesDelCoordinador();
        if (comunidadId != null) {
            seguridadService.verificarComunidadPropia(comunidadId);
            ids = Set.of(comunidadId);
        }
        if (ids.isEmpty()) {
            return List.of();
        }
        return solicitudRepository.findByComunidadIdInAndEstado(new ArrayList<>(ids), EstadoSolicitud.PENDIENTE)
                .stream()
                .map(this::convertir)
                .collect(Collectors.toList());
    }

    /** Perfil del solicitante (el coordinador lo consulta antes de decidir). */
    @Transactional(readOnly = true)
    public SolicitudIncorporacionResponseDTO obtener(Long id) {
        SolicitudIncorporacion s = solicitudRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Solicitud no encontrada con ID: " + id));
        Usuario usuario = seguridadService.usuarioActual();
        if (seguridadService.esCoordinador(usuario)) {
            seguridadService.verificarComunidadPropia(s.getComunidad().getId());
        } else if (!s.getUsuario().getId().equals(usuario.getId())) {
            throw new AccesoDenegadoException("No puede consultar esta solicitud.");
        }
        return convertir(s);
    }

    @Transactional
    public SolicitudIncorporacionResponseDTO aprobar(Long id) {
        Coordinador coordinador = seguridadService.requerirCoordinadorActual();
        SolicitudIncorporacion solicitud = cargarPendienteDeMiComunidad(id);
        incorporar(solicitud, coordinador, coordinador.getUsuario(), null);
        return convertir(solicitud);
    }

    @Transactional
    public SolicitudIncorporacionResponseDTO rechazar(Long id, String observaciones) {
        Coordinador coordinador = seguridadService.requerirCoordinadorActual();
        SolicitudIncorporacion solicitud = cargarPendienteDeMiComunidad(id);
        solicitud.setEstado(EstadoSolicitud.RECHAZADA);
        solicitud.setFechaRespuesta(LocalDateTime.now());
        solicitud.setCoordinador(coordinador);
        solicitud.setObservaciones(observaciones != null && !observaciones.isBlank() ? observaciones.trim() : null);
        solicitudRepository.save(solicitud);
        historialService.registrar(EntidadHistorial.SOLICITUD, solicitud.getId(),
                ConvertidorDTO.nombreCompleto(solicitud.getUsuario()), null, solicitud.getComunidad(), null,
                "SOLICITUD RECHAZADA", solicitud.getObservaciones(), coordinador.getUsuario());
        notificacionService.notificar(solicitud.getUsuario(), "Solicitud rechazada",
                "Tu solicitud para unirte a " + solicitud.getComunidad().getNombre() + " fue rechazada"
                        + (solicitud.getObservaciones() != null ? ": " + solicitud.getObservaciones() : "."),
                TipoNotificacion.SOLICITUD_RECHAZADA, solicitud.getId(), "SOLICITUD");
        return convertir(solicitud);
    }

    /**
     * Crea el perfil de apadrinado y su expediente, registra el uso del
     * código, le asigna las actividades de toda la comunidad y le notifica.
     */
    private void incorporar(SolicitudIncorporacion solicitud, Coordinador coordinador, Usuario quien, String nota) {
        Apadrinado apadrinado = apadrinadoRepository.save(Apadrinado.builder()
                .usuario(solicitud.getUsuario())
                .coordinador(coordinador)
                .comunidad(solicitud.getComunidad())
                .build());
        if (!expedienteRepository.existsByApadrinadoId(apadrinado.getId())) {
            expedienteRepository.save(Expediente.builder()
                    .apadrinado(apadrinado)
                    .fechaCreacion(LocalDate.now())
                    .build());
        }
        codigoAccesoRepository.findByCodigo(solicitud.getCodigo()).ifPresent(codigoAccesoService::registrarUso);

        solicitud.setEstado(EstadoSolicitud.APROBADA);
        solicitud.setFechaRespuesta(LocalDateTime.now());
        solicitud.setCoordinador(coordinador);
        solicitud.setObservaciones(nota);
        solicitudRepository.save(solicitud);

        historialService.registrar(EntidadHistorial.SOLICITUD, solicitud.getId(),
                ConvertidorDTO.nombreCompleto(solicitud.getUsuario()), apadrinado, solicitud.getComunidad(), null,
                "SOLICITUD ACEPTADA", nota, quien);
        notificacionService.notificar(solicitud.getUsuario(), "Solicitud aceptada",
                "¡Bienvenido a " + solicitud.getComunidad().getNombre() + "! Ya puedes ver tu comunidad y tus actividades.",
                TipoNotificacion.SOLICITUD_ACEPTADA, solicitud.getId(), "SOLICITUD");
        actividadService.asignarActividadesDeComunidad(apadrinado, quien);
    }

    private Coordinador responsableDe(Comunidad comunidad) {
        return coordinadorRepository.findAll().stream()
                .filter(c -> SeguridadService.comunidadesDe(c).contains(comunidad.getId()))
                .findFirst()
                .orElse(null);
    }

    private SolicitudIncorporacion cargarPendienteDeMiComunidad(Long id) {
        SolicitudIncorporacion solicitud = solicitudRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Solicitud no encontrada con ID: " + id));
        if (solicitud.getEstado() != EstadoSolicitud.PENDIENTE) {
            throw new RuntimeException("La solicitud ya fue resuelta.");
        }
        if (solicitud.getComunidad() == null
                || !seguridadService.comunidadesDelCoordinador().contains(solicitud.getComunidad().getId())) {
            throw new AccesoDenegadoException("La solicitud no pertenece a su comunidad.");
        }
        if (apadrinadoRepository.existsByUsuarioId(solicitud.getUsuario().getId())) {
            throw new RuntimeException("El usuario ya pertenece a una comunidad.");
        }
        return solicitud;
    }

    private SolicitudIncorporacionResponseDTO convertir(SolicitudIncorporacion s) {
        Usuario u = s.getUsuario();
        return SolicitudIncorporacionResponseDTO.builder()
                .id(s.getId())
                .usuarioId(u.getId())
                .usuarioNombre(u.getNombre())
                .usuarioApellido(u.getApellido())
                .usuarioCorreo(u.getCorreo())
                .usuarioTelefono(u.getTelefono())
                .usuarioDireccion(u.getDireccion())
                .usuarioFechaNacimiento(u.getFechaNacimiento())
                .comunidadId(s.getComunidad().getId())
                .comunidadNombre(s.getComunidad().getNombre())
                .codigo(s.getCodigo())
                .estado(s.getEstado().name())
                .fechaSolicitud(s.getFechaSolicitud())
                .fechaRespuesta(s.getFechaRespuesta())
                .observaciones(s.getObservaciones())
                .build();
    }
}
