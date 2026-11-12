package com.example.backend.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.example.backend.config.AccesoDenegadoException;
import com.example.backend.dto.AsignacionDetalleDTO;
import com.example.backend.dto.CartaRequestDTO;
import com.example.backend.dto.CartaResponseDTO;
import com.example.backend.dto.DocumentoResponseDTO;
import com.example.backend.dto.EntregaResponseDTO;
import com.example.backend.dto.HistorialActividadResponseDTO;
import com.example.backend.entity.Actividad;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Asignacion;
import com.example.backend.entity.Carta;
import com.example.backend.entity.Carta.EstadoCarta;
import com.example.backend.entity.Carta.TipoCarta;
import com.example.backend.entity.Documento;
import com.example.backend.entity.EntidadHistorial;
import com.example.backend.entity.Entrega;
import com.example.backend.entity.EstadoActividad;
import com.example.backend.entity.EstadoEntrega;
import com.example.backend.entity.Expediente;
import com.example.backend.entity.Observacion;
import com.example.backend.entity.OrigenDocumento;
import com.example.backend.entity.Sugerencia;
import com.example.backend.entity.TipoDocumento;
import com.example.backend.entity.TipoNotificacion;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.AsignacionRepository;
import com.example.backend.repository.CartaRepository;
import com.example.backend.repository.DocumentoRepository;
import com.example.backend.repository.EntregaRepository;
import com.example.backend.repository.ExpedienteRepository;
import com.example.backend.repository.ObservacionRepository;
import com.example.backend.repository.SugerenciaRepository;

import lombok.RequiredArgsConstructor;

/**
 * Entregas de tareas y su revisión.
 *
 * Flujo: Actividad → Entrega → Revisión → Sugerencias y corrección (se
 * repite si es necesario) → Aprobación → Actualización del expediente.
 *
 * El apadrinado prepara un borrador (documentos, fotografías, evidencias,
 * cartas y comentario) y lo envía. Si el coordinador solicita una
 * corrección, la siguiente versión parte de los archivos de la anterior.
 * Todas las versiones y sugerencias quedan registradas.
 */
@Service
@RequiredArgsConstructor
public class EntregaService {

    private final AsignacionRepository asignacionRepository;
    private final EntregaRepository entregaRepository;
    private final DocumentoRepository documentoRepository;
    private final CartaRepository cartaRepository;
    private final SugerenciaRepository sugerenciaRepository;
    private final ObservacionRepository observacionRepository;
    private final ExpedienteRepository expedienteRepository;
    private final DocumentoService documentoService;
    private final NotificacionService notificacionService;
    private final HistorialActividadService historialService;
    private final SeguridadService seguridadService;
    private final ConvertidorDTO convertidor;

    // ==================== CONSULTA ====================

    /** Asignación con la actividad, el material y todas las versiones de la entrega. */
    @Transactional(readOnly = true)
    public AsignacionDetalleDTO detalle(Long asignacionId) {
        Asignacion s = seguridadService.verificarAsignacionAccesible(asignacionId);
        List<EntregaResponseDTO> entregas = entregaRepository.findByAsignacionIdOrderByVersionDesc(asignacionId)
                .stream().map(convertidor::entrega).collect(Collectors.toList());
        boolean esApadrinado = seguridadService.esApadrinado(seguridadService.usuarioActual());
        return AsignacionDetalleDTO.builder()
                .asignacion(convertidor.asignacion(s, false))
                .actividad(convertidor.actividad(s.getActividad(), true, false))
                .entregas(entregas)
                .editable(esApadrinado && editable(s))
                .build();
    }

    @Transactional(readOnly = true)
    public List<HistorialActividadResponseDTO> historial(Long asignacionId) {
        seguridadService.verificarAsignacionDelCoordinador(asignacionId);
        return historialService.listarPorAsignacion(asignacionId);
    }

    /** El apadrinado puede trabajar en la entrega mientras no esté enviada ni aprobada. */
    private static boolean editable(Asignacion s) {
        if (!s.getActividad().esTarea()) {
            return false;
        }
        return switch (s.getEstado()) {
            case PENDIENTE, EN_PROGRESO, CORRECCION_SOLICITADA, VENCIDO -> true;
            default -> false;
        };
    }

    // ==================== APADRINADO: PREPARAR LA ENTREGA ====================

    /**
     * Devuelve el borrador de la entrega, creándolo si no existe. Tras una
     * corrección, la nueva versión parte de los archivos y cartas de la
     * versión anterior.
     */
    @Transactional
    public Entrega borrador(Asignacion s) {
        if (!editable(s)) {
            throw new RuntimeException(s.getActividad().esTarea()
                    ? "La entrega ya fue enviada y no se puede modificar."
                    : "Esta actividad no requiere entrega.");
        }
        Entrega ultima = entregaRepository.findFirstByAsignacionIdOrderByVersionDesc(s.getId()).orElse(null);
        if (ultima != null && ultima.getEstado() == EstadoEntrega.BORRADOR) {
            return ultima;
        }
        Entrega nueva = entregaRepository.save(Entrega.builder()
                .asignacion(s)
                .version(ultima == null ? 1 : ultima.getVersion() + 1)
                .estado(EstadoEntrega.BORRADOR)
                .fechaCreacion(LocalDateTime.now())
                .build());
        if (ultima != null) {
            for (Documento d : documentoRepository.findByEntregaId(ultima.getId())) {
                documentoService.copiarAEntrega(d, nueva);
            }
            for (Carta c : cartaRepository.findByEntregaId(ultima.getId())) {
                cartaRepository.save(Carta.builder()
                        .titulo(c.getTitulo())
                        .contenido(c.getContenido())
                        .tipoCarta(c.getTipoCarta())
                        .estado(EstadoCarta.BORRADOR)
                        .fechaCreacion(c.getFechaCreacion())
                        .expediente(c.getExpediente())
                        .actividad(c.getActividad())
                        .apadrinado(c.getApadrinado())
                        .escritoPor(c.getEscritoPor())
                        .entrega(nueva)
                        .build());
            }
        }
        if (s.getEstado() == EstadoActividad.PENDIENTE) {
            s.setEstado(EstadoActividad.EN_PROGRESO);
            s.setFechaInicio(LocalDateTime.now());
            asignacionRepository.save(s);
            historialService.registrarAsignacion(s, EntidadHistorial.ENTREGA, nueva.getId(),
                    EstadoActividad.PENDIENTE, EstadoActividad.EN_PROGRESO, "ENTREGA INICIADA",
                    null, s.getApadrinado().getUsuario());
        }
        return nueva;
    }

    @Transactional
    public EntregaResponseDTO iniciar(Long asignacionId) {
        Asignacion s = seguridadService.verificarAsignacionDelApadrinado(asignacionId);
        return convertidor.entrega(borrador(s));
    }

    /**
     * Sube un documento, fotografía o evidencia a la entrega en preparación.
     */
    @Transactional
    public DocumentoResponseDTO subirArchivo(Long asignacionId, MultipartFile file, TipoDocumento tipo, String descripcion) {
        Asignacion s = seguridadService.verificarAsignacionDelApadrinado(asignacionId);
        Entrega entrega = borrador(s);
        Apadrinado apadrinado = s.getApadrinado();
        if (tipo == TipoDocumento.MATERIAL) {
            tipo = null;
        }
        Documento doc = documentoService.guardar(file, tipo, OrigenDocumento.APADRINADO, s.getActividad(),
                entrega, expediente(apadrinado), apadrinado.getUsuario(), descripcion);
        historialService.registrarAsignacion(s, EntidadHistorial.DOCUMENTO, doc.getId(), s.getEstado(), s.getEstado(),
                "ARCHIVO CARGADO", doc.getTipoDocumento() + ": " + doc.getNombreOriginal() + " (versión "
                        + entrega.getVersion() + ")", apadrinado.getUsuario());
        return convertidor.documento(doc);
    }

    @Transactional
    public void eliminarArchivo(Long asignacionId, Long documentoId) {
        Asignacion s = seguridadService.verificarAsignacionDelApadrinado(asignacionId);
        Entrega entrega = borrador(s);
        Documento doc = documentoService.obtenerEntidad(documentoId);
        if (doc.getEntrega() == null || !doc.getEntrega().getId().equals(entrega.getId())) {
            throw new AccesoDenegadoException("Solo puede quitar archivos de la entrega en preparación.");
        }
        historialService.registrarAsignacion(s, EntidadHistorial.DOCUMENTO, doc.getId(), s.getEstado(), s.getEstado(),
                "ARCHIVO QUITADO", doc.getNombreOriginal(), s.getApadrinado().getUsuario());
        documentoService.eliminar(doc);
    }

    @Transactional
    public CartaResponseDTO guardarCarta(Long asignacionId, Long cartaId, CartaRequestDTO dto) {
        Asignacion s = seguridadService.verificarAsignacionDelApadrinado(asignacionId);
        Entrega entrega = borrador(s);
        if (dto.getContenido() == null || dto.getContenido().isBlank()) {
            throw new RuntimeException("La carta no puede estar vacía.");
        }
        Apadrinado apadrinado = s.getApadrinado();
        Carta carta;
        if (cartaId != null) {
            carta = cartaDelBorrador(cartaId, entrega);
        } else {
            carta = Carta.builder()
                    .estado(EstadoCarta.BORRADOR)
                    .expediente(expediente(apadrinado))
                    .actividad(s.getActividad())
                    .apadrinado(apadrinado)
                    .escritoPor(apadrinado.getUsuario())
                    .entrega(entrega)
                    .build();
        }
        carta.setTitulo(dto.getTitulo() != null && !dto.getTitulo().isBlank()
                ? dto.getTitulo().trim() : "Carta - " + s.getActividad().getTitulo());
        carta.setContenido(dto.getContenido().trim());
        carta.setTipoCarta(tipoCarta(dto.getTipoCarta()));
        carta = cartaRepository.save(carta);
        historialService.registrarAsignacion(s, EntidadHistorial.CARTA, carta.getId(), s.getEstado(), s.getEstado(),
                cartaId == null ? "CARTA ESCRITA" : "CARTA EDITADA", carta.getTitulo(), apadrinado.getUsuario());
        return convertidor.carta(carta);
    }

    @Transactional
    public void eliminarCarta(Long asignacionId, Long cartaId) {
        Asignacion s = seguridadService.verificarAsignacionDelApadrinado(asignacionId);
        Carta carta = cartaDelBorrador(cartaId, borrador(s));
        historialService.registrarAsignacion(s, EntidadHistorial.CARTA, carta.getId(), s.getEstado(), s.getEstado(),
                "CARTA QUITADA", carta.getTitulo(), s.getApadrinado().getUsuario());
        cartaRepository.delete(carta);
    }

    private Carta cartaDelBorrador(Long cartaId, Entrega entrega) {
        Carta carta = cartaRepository.findById(cartaId)
                .orElseThrow(() -> new RuntimeException("Carta no encontrada con ID: " + cartaId));
        if (carta.getEntrega() == null || !carta.getEntrega().getId().equals(entrega.getId())) {
            throw new AccesoDenegadoException("Solo puede modificar las cartas de la entrega en preparación.");
        }
        return carta;
    }

    private static TipoCarta tipoCarta(String valor) {
        if (valor == null || valor.isBlank()) {
            return TipoCarta.GENERAL;
        }
        try {
            return TipoCarta.valueOf(valor.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            return TipoCarta.GENERAL;
        }
    }

    /**
     * Envía la entrega para revisión. Valida que incluya lo que la tarea
     * requiere (documentos, fotografías y cartas).
     */
    @Transactional
    public EntregaResponseDTO enviar(Long asignacionId, String comentario) {
        Asignacion s = seguridadService.verificarAsignacionDelApadrinado(asignacionId);
        Entrega entrega = borrador(s);
        Actividad a = s.getActividad();
        List<Documento> docs = documentoRepository.findByEntregaId(entrega.getId());
        List<Carta> cartas = cartaRepository.findByEntregaId(entrega.getId());

        if (docs.isEmpty() && cartas.isEmpty()) {
            throw new RuntimeException("Agregue al menos un archivo o una carta antes de enviar.");
        }
        long fotos = docs.stream().filter(d -> d.getTipoDocumento() == TipoDocumento.FOTOGRAFIA).count();
        if (Boolean.TRUE.equals(a.getRequiereFotografia()) && fotos == 0) {
            throw new RuntimeException("La actividad requiere al menos una fotografía.");
        }
        if (Boolean.TRUE.equals(a.getRequiereDocumento()) && docs.size() - fotos == 0) {
            throw new RuntimeException("La actividad requiere al menos un documento.");
        }
        if (Boolean.TRUE.equals(a.getRequiereCarta()) && cartas.isEmpty()) {
            throw new RuntimeException("La actividad requiere al menos una carta.");
        }

        LocalDateTime ahora = LocalDateTime.now();
        if (comentario != null) {
            entrega.setComentario(comentario.isBlank() ? null : comentario.trim());
        }
        entrega.setEstado(EstadoEntrega.ENVIADA);
        entrega.setFechaEnvio(ahora);
        entregaRepository.save(entrega);
        for (Carta c : cartas) {
            c.setEstado(EstadoCarta.ENVIADA);
            c.setFechaEnvio(ahora);
        }
        cartaRepository.saveAll(cartas);

        EstadoActividad anterior = s.getEstado();
        s.setEstado(EstadoActividad.ENVIADO);
        s.setFechaEnvio(ahora);
        asignacionRepository.save(s);

        Usuario usuario = s.getApadrinado().getUsuario();
        historialService.registrarAsignacion(s, EntidadHistorial.ENTREGA, entrega.getId(), anterior,
                EstadoActividad.ENVIADO, "ENTREGA ENVIADA",
                "Versión " + entrega.getVersion() + ": " + docs.size() + " archivo(s), " + cartas.size() + " carta(s)"
                        + (entrega.getComentario() != null ? " · Comentario: " + entrega.getComentario() : ""),
                usuario);
        if (a.getCoordinador() != null) {
            notificacionService.notificar(a.getCoordinador().getUsuario(),
                    "Nueva entrega para revisar",
                    ConvertidorDTO.nombre(s.getApadrinado()) + " envió '" + a.getTitulo() + "'"
                            + (entrega.getVersion() > 1 ? " (versión " + entrega.getVersion() + ")" : ""),
                    TipoNotificacion.ENTREGA_ACTIVIDAD, s.getId(), "ASIGNACION");
        }
        notificacionService.notificar(usuario, "Documento enviado",
                "Tu entrega de '" + a.getTitulo() + "' fue enviada al coordinador.",
                TipoNotificacion.DOCUMENTO_SUBIDO, s.getId(), "ASIGNACION");
        return convertidor.entrega(entrega);
    }

    // ==================== COORDINADOR: REVISIÓN ====================

    /** El coordinador comienza a revisar la entrega enviada. */
    @Transactional
    public EntregaResponseDTO iniciarRevision(Long asignacionId) {
        Asignacion s = seguridadService.verificarAsignacionDelCoordinador(asignacionId);
        Entrega entrega = ultimaEnviada(s);
        if (s.getEstado() == EstadoActividad.ENVIADO) {
            Usuario revisor = seguridadService.usuarioActual();
            entrega.setEstado(EstadoEntrega.EN_REVISION);
            entrega.setRevisor(revisor);
            entregaRepository.save(entrega);
            s.setEstado(EstadoActividad.EN_REVISION);
            asignacionRepository.save(s);
            historialService.registrarAsignacion(s, EntidadHistorial.ENTREGA, entrega.getId(),
                    EstadoActividad.ENVIADO, EstadoActividad.EN_REVISION, "REVISIÓN INICIADA",
                    "Versión " + entrega.getVersion(), revisor);
            notificacionService.notificar(s.getApadrinado().getUsuario(), "Documento en revisión",
                    "El coordinador está revisando tu entrega de '" + s.getActividad().getTitulo() + "'.",
                    TipoNotificacion.ACTIVIDAD_EN_REVISION, s.getId(), "ASIGNACION");
        }
        return convertidor.entrega(entrega);
    }

    /** Aprueba la entrega: la actividad queda completada satisfactoriamente. */
    @Transactional
    public EntregaResponseDTO aprobar(Long asignacionId, String observacion) {
        Asignacion s = seguridadService.verificarAsignacionDelCoordinador(asignacionId);
        Entrega entrega = enRevision(s);
        Usuario revisor = seguridadService.usuarioActual();
        LocalDateTime ahora = LocalDateTime.now();

        entrega.setEstado(EstadoEntrega.APROBADA);
        entrega.setRevisor(revisor);
        entrega.setFechaRevision(ahora);
        entregaRepository.save(entrega);
        List<Carta> cartas = cartaRepository.findByEntregaId(entrega.getId());
        cartas.forEach(c -> c.setEstado(EstadoCarta.APROBADA));
        cartaRepository.saveAll(cartas);

        EstadoActividad anterior = s.getEstado();
        s.setEstado(EstadoActividad.APROBADO);
        s.setFechaAprobacion(ahora);
        asignacionRepository.save(s);

        String texto = observacion != null && !observacion.isBlank() ? observacion.trim() : null;
        if (texto != null) {
            observacionRepository.save(Observacion.builder()
                    .expediente(expediente(s.getApadrinado()))
                    .asignacion(s)
                    .texto(texto)
                    .autor(revisor)
                    .fecha(ahora)
                    .build());
        }
        historialService.registrarAsignacion(s, EntidadHistorial.ENTREGA, entrega.getId(), anterior,
                EstadoActividad.APROBADO, "ENTREGA APROBADA",
                "Versión " + entrega.getVersion() + (texto != null ? " · " + texto : ""), revisor);
        notificacionService.notificar(s.getApadrinado().getUsuario(), "Actividad aprobada",
                "¡Tu entrega de '" + s.getActividad().getTitulo() + "' fue aprobada!",
                TipoNotificacion.ACTIVIDAD_APROBADA, s.getId(), "ASIGNACION");
        return convertidor.entrega(entrega);
    }

    /**
     * Solicita una corrección: las sugerencias de mejora son obligatorias.
     */
    @Transactional
    public EntregaResponseDTO solicitarCorreccion(Long asignacionId, String sugerencias) {
        if (sugerencias == null || sugerencias.isBlank()) {
            throw new RuntimeException("Escriba las sugerencias de mejora para el apadrinado.");
        }
        Asignacion s = seguridadService.verificarAsignacionDelCoordinador(asignacionId);
        Entrega entrega = enRevision(s);
        Usuario revisor = seguridadService.usuarioActual();
        LocalDateTime ahora = LocalDateTime.now();

        entrega.setEstado(EstadoEntrega.CORRECCION_SOLICITADA);
        entrega.setRevisor(revisor);
        entrega.setFechaRevision(ahora);
        entregaRepository.save(entrega);
        sugerenciaRepository.save(Sugerencia.builder()
                .entrega(entrega)
                .texto(sugerencias.trim())
                .autor(revisor)
                .fecha(ahora)
                .build());
        List<Carta> cartas = cartaRepository.findByEntregaId(entrega.getId());
        cartas.forEach(c -> c.setEstado(EstadoCarta.RECHAZADA));
        cartaRepository.saveAll(cartas);

        EstadoActividad anterior = s.getEstado();
        s.setEstado(EstadoActividad.CORRECCION_SOLICITADA);
        s.setRecordatorioEnviado(false);
        asignacionRepository.save(s);

        historialService.registrarAsignacion(s, EntidadHistorial.ENTREGA, entrega.getId(), anterior,
                EstadoActividad.CORRECCION_SOLICITADA, "CORRECCIÓN SOLICITADA",
                "Versión " + entrega.getVersion() + " · Sugerencias: " + sugerencias.trim(), revisor);
        notificacionService.notificar(s.getApadrinado().getUsuario(), "Corrección solicitada",
                "El coordinador pidió correcciones en '" + s.getActividad().getTitulo() + "': " + sugerencias.trim(),
                TipoNotificacion.CORRECCION_SOLICITADA, s.getId(), "ASIGNACION");
        return convertidor.entrega(entrega);
    }

    /** Entrega a revisar: si estaba recién enviada, pasa primero a En revisión. */
    private Entrega enRevision(Asignacion s) {
        if (s.getEstado() == EstadoActividad.ENVIADO) {
            iniciarRevision(s.getId());
        }
        if (s.getEstado() != EstadoActividad.EN_REVISION) {
            throw new RuntimeException("Solo se pueden revisar entregas enviadas por el apadrinado.");
        }
        return ultimaEnviada(s);
    }

    private Entrega ultimaEnviada(Asignacion s) {
        Entrega e = entregaRepository.findFirstByAsignacionIdOrderByVersionDesc(s.getId())
                .orElseThrow(() -> new RuntimeException("El apadrinado aún no ha enviado una entrega."));
        if (e.getEstado() == EstadoEntrega.BORRADOR) {
            throw new RuntimeException("El apadrinado aún no ha enviado la entrega.");
        }
        return e;
    }

    private Expediente expediente(Apadrinado apadrinado) {
        return expedienteRepository.findByApadrinadoId(apadrinado.getId())
                .orElseGet(() -> expedienteRepository.save(Expediente.builder()
                        .apadrinado(apadrinado)
                        .fechaCreacion(java.time.LocalDate.now())
                        .build()));
    }
}
