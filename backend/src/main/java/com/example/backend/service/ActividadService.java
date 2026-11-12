package com.example.backend.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.example.backend.config.AccesoDenegadoException;
import com.example.backend.config.ConfirmacionRequeridaException;
import com.example.backend.dto.ActividadDetalleDTO;
import com.example.backend.dto.ActividadRequestDTO;
import com.example.backend.dto.ActividadResponseDTO;
import com.example.backend.dto.AsignacionResponseDTO;
import com.example.backend.dto.DocumentoResponseDTO;
import com.example.backend.dto.MiComunidadDTO;
import com.example.backend.dto.ModuloContenidoDTO;
import com.example.backend.dto.TableroApadrinadoDTO;
import com.example.backend.entity.Actividad;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Asignacion;
import com.example.backend.entity.Comunidad;
import com.example.backend.entity.Coordinador;
import com.example.backend.entity.Documento;
import com.example.backend.entity.EntidadHistorial;
import com.example.backend.entity.Entrega;
import com.example.backend.entity.EstadoActividad;
import com.example.backend.entity.EstadoEntrega;
import com.example.backend.entity.Modulo;
import com.example.backend.entity.OrigenDocumento;
import com.example.backend.entity.TipoActividad;
import com.example.backend.entity.TipoNotificacion;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ActividadRepository;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.AsignacionRepository;
import com.example.backend.repository.CartaRepository;
import com.example.backend.repository.ComunidadRepository;
import com.example.backend.repository.DocumentoRepository;
import com.example.backend.repository.EntregaRepository;
import com.example.backend.repository.ExportacionRepository;
import com.example.backend.repository.HistorialActividadRepository;
import com.example.backend.repository.ModuloRepository;
import com.example.backend.repository.ObservacionRepository;

import lombok.RequiredArgsConstructor;

/**
 * Gestión de actividades (CRUD, tipos y asignaciones).
 *
 * Toda actividad se crea dentro de un módulo de una comunidad y solo se
 * asigna a apadrinados de esa comunidad: a toda la comunidad o a los
 * seleccionados. Por cada apadrinado se crea una {@link Asignacion} con
 * su propio estado.
 */
@Service
@RequiredArgsConstructor
public class ActividadService {

    /** Estados de una tarea "en proceso" para el apadrinado. */
    public static final Set<EstadoActividad> EN_PROCESO = EnumSet.of(
            EstadoActividad.PENDIENTE, EstadoActividad.EN_PROGRESO, EstadoActividad.ENVIADO,
            EstadoActividad.EN_REVISION, EstadoActividad.CORRECCION_SOLICITADA, EstadoActividad.VENCIDO);

    /** Estados que aparecen en el tablero de pendientes del apadrinado. */
    public static final Set<EstadoActividad> PENDIENTES = EnumSet.of(
            EstadoActividad.PENDIENTE, EstadoActividad.EN_PROGRESO, EstadoActividad.CORRECCION_SOLICITADA);

    private final ActividadRepository actividadRepository;
    private final AsignacionRepository asignacionRepository;
    private final EntregaRepository entregaRepository;
    private final ApadrinadoRepository apadrinadoRepository;
    private final ComunidadRepository comunidadRepository;
    private final ModuloRepository moduloRepository;
    private final DocumentoRepository documentoRepository;
    private final CartaRepository cartaRepository;
    private final HistorialActividadRepository historialRepository;
    private final ExportacionRepository exportacionRepository;
    private final ObservacionRepository observacionRepository;
    private final DocumentoService documentoService;
    private final ModuloService moduloService;
    private final NotificacionService notificacionService;
    private final HistorialActividadService historialService;
    private final SeguridadService seguridadService;
    private final ConvertidorDTO convertidor;

    // ==================== COORDINADOR: TABLERO Y DETALLE ====================

    /**
     * Tablero de actividades del coordinador, filtrable por comunidad,
     * módulo y tipo. Cada actividad incluye el resumen de avance.
     */
    @Transactional(readOnly = true)
    public List<ActividadResponseDTO> tablero(Long comunidadId, Long moduloId, TipoActividad tipo) {
        Coordinador coordinador = seguridadService.requerirCoordinadorActual();
        Set<Long> comunidades = SeguridadService.comunidadesDe(coordinador);
        if (comunidadId != null) {
            seguridadService.verificarComunidadPropia(comunidadId);
            comunidades = Set.of(comunidadId);
        }
        if (comunidades.isEmpty()) {
            return List.of();
        }
        return actividadRepository.findByComunidadIdInAndEliminadaFalseOrderByFechaCreacionDesc(comunidades)
                .stream()
                .filter(a -> moduloId == null || (a.getModulo() != null && a.getModulo().getId().equals(moduloId)))
                .filter(a -> tipo == null || a.getTipo() == tipo)
                .map(a -> convertidor.actividad(a, false, true))
                .collect(Collectors.toList());
    }

    /**
     * Detalle de una actividad: datos, material adjunto y la lista de
     * apadrinados asignados con el estado de cada uno.
     */
    @Transactional(readOnly = true)
    public ActividadDetalleDTO detalle(Long actividadId) {
        Actividad actividad = seguridadService.verificarActividadPropia(actividadId);
        List<AsignacionResponseDTO> asignaciones = asignacionRepository
                .findByActividadIdOrderByApadrinadoUsuarioNombreAsc(actividadId).stream()
                .map(s -> convertidor.asignacion(s, false))
                .collect(Collectors.toList());
        boolean aprobadas = asignaciones.stream().anyMatch(s -> s.getEstado() == EstadoActividad.APROBADO);
        return ActividadDetalleDTO.builder()
                .actividad(convertidor.actividad(actividad, true, true))
                .asignaciones(asignaciones)
                .tieneEntregas(tieneEntregas(actividadId))
                .exportable(actividad.esTarea() && aprobadas)
                .build();
    }

    public boolean tieneEntregas(Long actividadId) {
        return entregaRepository.existsByAsignacionActividadIdAndEstadoNot(actividadId, EstadoEntrega.BORRADOR);
    }

    // ==================== COORDINADOR: CREAR ====================

    @Transactional
    public ActividadResponseDTO crear(ActividadRequestDTO dto) {
        Coordinador coordinador = seguridadService.requerirCoordinadorActual();
        Usuario usuario = coordinador.getUsuario();
        if (dto.getComunidadId() == null) {
            throw new RuntimeException("Seleccione la comunidad de la actividad.");
        }
        seguridadService.verificarComunidadPropia(dto.getComunidadId());
        Comunidad comunidad = comunidadRepository.findById(dto.getComunidadId())
                .orElseThrow(() -> new RuntimeException("Comunidad no encontrada con ID: " + dto.getComunidadId()));
        Modulo modulo = moduloService.resolverModulo(comunidad, dto.getModuloId());

        TipoActividad tipo = dto.getTipo() != null ? dto.getTipo() : TipoActividad.TAREA;
        Actividad actividad = Actividad.builder()
                .tipo(tipo)
                .titulo(obligatorio(dto.getTitulo(), "El nombre de la actividad es obligatorio."))
                .descripcion(limpiar(dto.getDescripcion()))
                .instrucciones(limpiar(dto.getInstrucciones()))
                .comunidad(comunidad)
                .modulo(modulo)
                .coordinador(coordinador)
                .asignadaAComunidad(!Boolean.FALSE.equals(dto.getAsignarAComunidad()))
                .fechaCreacion(LocalDateTime.now())
                .build();
        aplicarRequisitos(actividad, dto, true);

        List<Apadrinado> destinatarios = resolverDestinatarios(actividad, dto);
        actividad = actividadRepository.save(actividad);
        historialService.registrarActividad(actividad, "ACTIVIDAD CREADA",
                etiqueta(tipo) + " en " + modulo.getNombre() + " · asignada a "
                        + (actividad.getAsignadaAComunidad() ? "toda la comunidad" : destinatarios.size() + " apadrinado(s)"),
                usuario);

        for (Apadrinado apadrinado : destinatarios) {
            asignar(actividad, apadrinado, usuario);
        }
        return convertidor.actividad(actividad, true, true);
    }

    /**
     * Crea la asignación de la actividad para el apadrinado y le notifica.
     */
    @Transactional
    public Asignacion asignar(Actividad actividad, Apadrinado apadrinado, Usuario usuario) {
        EstadoActividad inicial = actividad.esTarea() ? EstadoActividad.PENDIENTE : EstadoActividad.PUBLICADO;
        Asignacion asignacion = asignacionRepository.save(Asignacion.builder()
                .actividad(actividad)
                .apadrinado(apadrinado)
                .estado(inicial)
                .fechaAsignacion(LocalDateTime.now())
                .build());
        historialService.registrarAsignacion(asignacion, EntidadHistorial.ASIGNACION, asignacion.getId(),
                null, inicial, "ACTIVIDAD ASIGNADA", null, usuario);
        notificarAsignacion(asignacion);
        return asignacion;
    }

    private void notificarAsignacion(Asignacion asignacion) {
        Actividad a = asignacion.getActividad();
        String titulo;
        TipoNotificacion tipo;
        String mensaje;
        switch (a.getTipo()) {
            case ANUNCIO -> {
                titulo = "Nuevo anuncio";
                tipo = TipoNotificacion.NUEVO_ANUNCIO;
                mensaje = "Tu coordinador publicó el anuncio: '" + a.getTitulo() + "'";
            }
            case MATERIAL_APOYO -> {
                titulo = "Nuevo material de apoyo";
                tipo = TipoNotificacion.NUEVO_MATERIAL;
                mensaje = "Hay nuevo material de apoyo disponible: '" + a.getTitulo() + "'";
            }
            default -> {
                titulo = "Nueva actividad asignada";
                tipo = TipoNotificacion.NUEVA_ACTIVIDAD;
                mensaje = "Se te asignó la actividad: '" + a.getTitulo() + "'"
                        + (a.getFechaLimite() != null ? ". Fecha límite: " + a.getFechaLimite() : "");
            }
        }
        notificacionService.notificar(asignacion.getApadrinado().getUsuario(), titulo, mensaje, tipo,
                asignacion.getId(), "ASIGNACION");
    }

    /**
     * Al incorporarse un apadrinado a la comunidad recibe las actividades
     * asignadas a toda la comunidad que siguen vigentes.
     */
    @Transactional
    public void asignarActividadesDeComunidad(Apadrinado apadrinado, Usuario usuario) {
        if (apadrinado.getComunidad() == null) {
            return;
        }
        LocalDate hoy = LocalDate.now();
        for (Actividad a : actividadRepository
                .findByComunidadIdAndAsignadaAComunidadTrueAndEliminadaFalse(apadrinado.getComunidad().getId())) {
            boolean vigente = !a.esTarea() || a.getFechaLimite() == null || !a.getFechaLimite().isBefore(hoy);
            if (vigente && !asignacionRepository.existsByActividadIdAndApadrinadoId(a.getId(), apadrinado.getId())) {
                asignar(a, apadrinado, usuario);
            }
        }
    }

    // ==================== COORDINADOR: EDITAR ====================

    @Transactional
    public ActividadResponseDTO actualizar(Long id, ActividadRequestDTO dto) {
        Actividad actividad = seguridadService.verificarActividadPropia(id);
        if (Boolean.TRUE.equals(actividad.getEliminada())) {
            throw new RuntimeException("La actividad fue eliminada.");
        }
        Usuario usuario = seguridadService.usuarioActual();
        if (dto.getTipo() != null && dto.getTipo() != actividad.getTipo()) {
            throw new RuntimeException("El tipo de una actividad no se puede cambiar después de crearla.");
        }
        if (dto.getComunidadId() != null && !dto.getComunidadId().equals(actividad.getComunidad().getId())) {
            throw new RuntimeException("La comunidad de una actividad no se puede cambiar.");
        }
        List<String> cambios = new ArrayList<>();

        if (dto.getTitulo() != null && !dto.getTitulo().trim().equals(actividad.getTitulo())) {
            actividad.setTitulo(obligatorio(dto.getTitulo(), "El nombre de la actividad es obligatorio."));
            cambios.add("nombre");
        }
        if (dto.getDescripcion() != null && !Objects.equals(limpiar(dto.getDescripcion()), actividad.getDescripcion())) {
            actividad.setDescripcion(limpiar(dto.getDescripcion()));
            cambios.add("descripción");
        }
        if (dto.getInstrucciones() != null
                && !Objects.equals(limpiar(dto.getInstrucciones()), actividad.getInstrucciones())) {
            actividad.setInstrucciones(limpiar(dto.getInstrucciones()));
            cambios.add("instrucciones");
        }
        LocalDate fechaAnterior = actividad.getFechaLimite();
        String requisitosAntes = requisitos(actividad);
        aplicarRequisitos(actividad, dto, false);
        boolean cambioFecha = !Objects.equals(fechaAnterior, actividad.getFechaLimite());
        if (cambioFecha) {
            cambios.add("fecha límite");
        }
        if (!requisitosAntes.equals(requisitos(actividad))) {
            cambios.add("requisitos");
        }
        if (dto.getModuloId() != null && (actividad.getModulo() == null
                || !dto.getModuloId().equals(actividad.getModulo().getId()))) {
            actividad.setModulo(moduloService.resolverModulo(actividad.getComunidad(), dto.getModuloId()));
            cambios.add("módulo");
        }

        // Apadrinados asignados
        List<Asignacion> actuales = asignacionRepository.findByActividadIdOrderByApadrinadoUsuarioNombreAsc(id);
        List<Apadrinado> nuevos = new ArrayList<>();
        if (dto.getAsignarAComunidad() != null || dto.getApadrinadoIds() != null) {
            if (dto.getAsignarAComunidad() != null) {
                actividad.setAsignadaAComunidad(dto.getAsignarAComunidad());
            }
            List<Apadrinado> destino = resolverDestinatarios(actividad, dto);
            Set<Long> idsDestino = destino.stream().map(Apadrinado::getId).collect(Collectors.toSet());
            Set<Long> idsActuales = actuales.stream().map(s -> s.getApadrinado().getId()).collect(Collectors.toSet());
            for (Asignacion s : new ArrayList<>(actuales)) {
                if (!idsDestino.contains(s.getApadrinado().getId())) {
                    quitarAsignacion(s, usuario);
                    actuales.remove(s);
                    cambios.add("asignados");
                }
            }
            for (Apadrinado ap : destino) {
                if (!idsActuales.contains(ap.getId())) {
                    nuevos.add(ap);
                }
            }
        }

        actividad.setFechaActualizacion(LocalDateTime.now());
        actividad = actividadRepository.save(actividad);

        if (cambioFecha) {
            reprogramarFecha(actividad, actuales, usuario);
        }
        for (Apadrinado ap : nuevos) {
            asignar(actividad, ap, usuario);
        }
        if (!nuevos.isEmpty()) {
            cambios.add("asignados");
        }

        String resumen = cambios.isEmpty() ? "Sin cambios" : "Cambios: " + String.join(", ", new LinkedHashSet<>(cambios));
        historialService.registrarActividad(actividad, "ACTIVIDAD EDITADA", resumen, usuario);

        // Los apadrinados ya asignados son notificados del cambio
        if (!cambios.isEmpty()) {
            for (Asignacion s : actuales) {
                notificacionService.notificar(s.getApadrinado().getUsuario(),
                        "Actividad modificada",
                        "El coordinador actualizó la actividad '" + actividad.getTitulo() + "' ("
                                + String.join(", ", new LinkedHashSet<>(cambios)) + ").",
                        TipoNotificacion.ACTIVIDAD_MODIFICADA, s.getId(), "ASIGNACION");
            }
        }
        return convertidor.actividad(actividad, true, true);
    }

    /** Si cambia la fecha límite se reinicia el recordatorio y se reabren las vencidas. */
    private void reprogramarFecha(Actividad actividad, List<Asignacion> asignaciones, Usuario usuario) {
        LocalDate hoy = LocalDate.now();
        for (Asignacion s : asignaciones) {
            s.setRecordatorioEnviado(false);
            if (s.getEstado() == EstadoActividad.VENCIDO
                    && (actividad.getFechaLimite() == null || !actividad.getFechaLimite().isBefore(hoy))) {
                EstadoActividad nuevo = s.getFechaInicio() != null ? EstadoActividad.EN_PROGRESO : EstadoActividad.PENDIENTE;
                historialService.registrarAsignacion(s, EntidadHistorial.ASIGNACION, s.getId(),
                        EstadoActividad.VENCIDO, nuevo, "ACTIVIDAD REABIERTA", "Nueva fecha límite: "
                                + actividad.getFechaLimite(), usuario);
                s.setEstado(nuevo);
            }
        }
        asignacionRepository.saveAll(asignaciones);
    }

    /** Quita la asignación; no se permite si el apadrinado ya entregó. */
    private void quitarAsignacion(Asignacion s, Usuario usuario) {
        if (entregaRepository.existsByAsignacionIdAndEstadoNot(s.getId(), EstadoEntrega.BORRADOR)) {
            throw new RuntimeException("No se puede quitar a " + ConvertidorDTO.nombre(s.getApadrinado())
                    + " de la actividad porque ya realizó una entrega.");
        }
        eliminarContenidoDeEntregas(s.getId());
        historialService.registrar(EntidadHistorial.ASIGNACION, s.getId(), s.getActividad().getTitulo(),
                s.getApadrinado(), s.getActividad().getComunidad(), s.getActividad(), "ASIGNACIÓN RETIRADA",
                ConvertidorDTO.nombre(s.getApadrinado()), usuario);
        // El historial y las observaciones se conservan sin la asignación
        historialRepository.desvincularAsignacion(s.getId());
        observacionRepository.desvincularAsignacion(s.getId());
        asignacionRepository.eliminarPorId(s.getId());
    }

    private void eliminarContenidoDeEntregas(Long asignacionId) {
        for (Entrega e : entregaRepository.findByAsignacionIdOrderByVersionDesc(asignacionId)) {
            documentoService.eliminarTodos(documentoRepository.findByEntregaId(e.getId()));
            cartaRepository.deleteAll(cartaRepository.findByEntregaId(e.getId()));
        }
        cartaRepository.flush();
    }

    // ==================== COORDINADOR: ELIMINAR ====================

    /**
     * Elimina la actividad. Si ya tiene entregas requiere confirmación y la
     * eliminación es lógica: deja de mostrarse pero sus entregas y archivos
     * se conservan en el expediente y en el historial. Sin entregas se
     * elimina de forma definitiva.
     *
     * @return "LOGICA" o "DEFINITIVA"
     */
    @Transactional
    public String eliminar(Long id, boolean confirmado) {
        Actividad actividad = seguridadService.verificarActividadPropia(id);
        Usuario usuario = seguridadService.usuarioActual();
        if (Boolean.TRUE.equals(actividad.getEliminada())) {
            throw new RuntimeException("La actividad ya fue eliminada.");
        }
        if (tieneEntregas(id)) {
            if (!confirmado) {
                throw new ConfirmacionRequeridaException("La actividad '" + actividad.getTitulo()
                        + "' ya tiene entregas. Se ocultará, pero sus entregas y archivos se conservarán "
                        + "en los expedientes y en el historial. ¿Desea continuar?");
            }
            actividad.setEliminada(true);
            actividad.setFechaEliminacion(LocalDateTime.now());
            actividadRepository.save(actividad);
            historialService.registrarActividad(actividad, "ACTIVIDAD ELIMINADA (LÓGICA)",
                    "Tenía entregas: se conservan en los expedientes", usuario);
            return "LOGICA";
        }

        String titulo = actividad.getTitulo();
        Comunidad comunidad = actividad.getComunidad();
        String detalle = "Eliminación definitiva (" + etiqueta(actividad.getTipo()) + " sin entregas)";
        for (Asignacion s : asignacionRepository.findByActividadIdOrderByApadrinadoUsuarioNombreAsc(id)) {
            eliminarContenidoDeEntregas(s.getId());
        }
        documentoService.eliminarTodos(documentoRepository.findByActividadId(id));
        cartaRepository.deleteAll(cartaRepository.findByActividadId(id));
        cartaRepository.flush();
        // El historial y las exportaciones se conservan sin la referencia a la actividad
        historialRepository.desvincularActividad(id);
        exportacionRepository.desvincularActividad(id);
        observacionRepository.desvincularActividad(id);
        asignacionRepository.eliminarPorActividad(id);
        actividadRepository.eliminarPorId(id);
        historialService.registrar(EntidadHistorial.ACTIVIDAD, id, titulo, null, comunidad, null,
                "ACTIVIDAD ELIMINADA", detalle, usuario);
        return "DEFINITIVA";
    }

    // ==================== COORDINADOR: CONTENIDO ADJUNTO ====================

    /** Sube contenido del coordinador (documentos, fotografías, material) a la actividad. */
    @Transactional
    public DocumentoResponseDTO subirAdjunto(Long actividadId, MultipartFile file, String descripcion) {
        Actividad actividad = seguridadService.verificarActividadPropia(actividadId);
        Usuario usuario = seguridadService.usuarioActual();
        Documento doc = documentoService.guardar(file, null, OrigenDocumento.COORDINADOR, actividad,
                null, null, usuario, descripcion);
        historialService.registrarActividad(actividad, "CONTENIDO AGREGADO", doc.getNombreOriginal(), usuario);
        return convertidor.documento(doc);
    }

    @Transactional
    public void eliminarAdjunto(Long actividadId, Long documentoId) {
        Actividad actividad = seguridadService.verificarActividadPropia(actividadId);
        Documento doc = documentoService.obtenerEntidad(documentoId);
        if (doc.getOrigen() != OrigenDocumento.COORDINADOR || doc.getActividad() == null
                || !doc.getActividad().getId().equals(actividadId)) {
            throw new AccesoDenegadoException("El archivo no es contenido de esta actividad.");
        }
        historialService.registrarActividad(actividad, "CONTENIDO ELIMINADO", doc.getNombreOriginal(),
                seguridadService.usuarioActual());
        documentoService.eliminar(doc);
    }

    // ==================== APADRINADO ====================

    /**
     * Tablero de pendientes: tareas Pendientes, En progreso y con
     * Corrección solicitada, ordenadas por fecha límite.
     */
    @Transactional(readOnly = true)
    public TableroApadrinadoDTO tableroApadrinado() {
        Apadrinado apadrinado = seguridadService.requerirApadrinadoActual();
        List<Asignacion> todas = asignacionRepository.findVisiblesPorApadrinado(apadrinado.getId());
        List<AsignacionResponseDTO> pendientes = todas.stream()
                .filter(s -> s.getActividad().esTarea() && PENDIENTES.contains(s.getEstado()))
                .sorted(Comparator
                        .comparing((Asignacion s) -> s.getActividad().getFechaLimite(),
                                Comparator.nullsLast(Comparator.naturalOrder()))
                        .thenComparing(Asignacion::getFechaAsignacion))
                .map(s -> convertidor.asignacion(s, true))
                .collect(Collectors.toList());
        return TableroApadrinadoDTO.builder()
                .pendientes(pendientes)
                .correcciones(pendientes.stream()
                        .filter(s -> s.getEstado() == EstadoActividad.CORRECCION_SOLICITADA).count())
                .proximasAVencer(pendientes.stream().filter(AsignacionResponseDTO::isProximaAVencer).count())
                .realizadas(todas.stream().filter(s -> s.getEstado() == EstadoActividad.APROBADO).count())
                .anunciosNuevos(todas.stream().filter(s -> s.getEstado() == EstadoActividad.PUBLICADO).count())
                .build();
    }

    /**
     * Comunidad del apadrinado, su coordinador y los módulos (en el orden
     * definido por el coordinador) con las actividades que le fueron
     * asignadas, separadas en proceso / realizadas / anuncios / material.
     */
    @Transactional(readOnly = true)
    public MiComunidadDTO miComunidad() {
        Apadrinado apadrinado = seguridadService.requerirApadrinadoActual();
        Comunidad comunidad = apadrinado.getComunidad();
        if (comunidad == null) {
            throw new RuntimeException("Aún no pertenece a una comunidad.");
        }
        List<Asignacion> asignaciones = asignacionRepository.findVisiblesPorApadrinado(apadrinado.getId());
        Map<Long, List<Asignacion>> porModulo = new HashMap<>();
        for (Asignacion s : asignaciones) {
            Long moduloId = s.getActividad().getModulo() != null ? s.getActividad().getModulo().getId() : null;
            porModulo.computeIfAbsent(moduloId, k -> new ArrayList<>()).add(s);
        }
        List<ModuloContenidoDTO> modulos = new ArrayList<>();
        for (Modulo m : moduloRepository.findByComunidadIdOrderByOrdenAscIdAsc(comunidad.getId())) {
            List<Asignacion> lista = porModulo.getOrDefault(m.getId(), List.of());
            modulos.add(ModuloContenidoDTO.builder()
                    .modulo(convertidor.modulo(m))
                    .enProceso(filtrar(lista, TipoActividad.TAREA, EN_PROCESO))
                    .realizadas(filtrar(lista, TipoActividad.TAREA, EnumSet.of(EstadoActividad.APROBADO)))
                    .anuncios(filtrar(lista, TipoActividad.ANUNCIO, null))
                    .material(filtrar(lista, TipoActividad.MATERIAL_APOYO, null))
                    .build());
        }
        Coordinador responsable = apadrinado.getCoordinador();
        return MiComunidadDTO.builder()
                .comunidad(ComunidadService.convertir(comunidad, null, (long) modulos.size()))
                .coordinadorNombre(responsable != null ? ConvertidorDTO.nombreCompleto(responsable.getUsuario()) : null)
                .coordinadorCorreo(responsable != null && responsable.getUsuario() != null
                        ? responsable.getUsuario().getCorreo() : null)
                .modulos(modulos)
                .build();
    }

    private List<AsignacionResponseDTO> filtrar(List<Asignacion> lista, TipoActividad tipo, Set<EstadoActividad> estados) {
        return lista.stream()
                .filter(s -> s.getActividad().getTipo() == tipo)
                .filter(s -> estados == null || estados.contains(s.getEstado()))
                .sorted(Comparator.comparing(Asignacion::getFechaAsignacion).reversed())
                .map(s -> convertidor.asignacion(s, true))
                .collect(Collectors.toList());
    }

    /** Todas las actividades asignadas al apadrinado actual. */
    @Transactional(readOnly = true)
    public List<AsignacionResponseDTO> misAsignaciones() {
        Apadrinado apadrinado = seguridadService.requerirApadrinadoActual();
        return asignacionRepository.findVisiblesPorApadrinado(apadrinado.getId()).stream()
                .map(s -> convertidor.asignacion(s, true))
                .collect(Collectors.toList());
    }

    /** Anuncio o material abierto por el apadrinado: Publicado → Visto. */
    @Transactional
    public AsignacionResponseDTO marcarVisto(Long asignacionId) {
        Asignacion s = seguridadService.verificarAsignacionDelApadrinado(asignacionId);
        if (!s.getActividad().esTarea() && s.getEstado() == EstadoActividad.PUBLICADO) {
            s.setEstado(EstadoActividad.VISTO);
            s.setFechaVisto(LocalDateTime.now());
            asignacionRepository.save(s);
            historialService.registrarAsignacion(s, EntidadHistorial.ASIGNACION, s.getId(),
                    EstadoActividad.PUBLICADO, EstadoActividad.VISTO, "VISTO", null,
                    s.getApadrinado().getUsuario());
        }
        return convertidor.asignacion(s, true);
    }

    // ==================== AUXILIARES ====================

    /** Solo las tareas tienen fecha límite y requisitos de entrega. */
    private void aplicarRequisitos(Actividad actividad, ActividadRequestDTO dto, boolean creacion) {
        if (!actividad.esTarea()) {
            actividad.setFechaLimite(null);
            actividad.setRequiereDocumento(false);
            actividad.setRequiereFotografia(false);
            actividad.setRequiereCarta(false);
            actividad.setOtrosRequisitos(null);
            return;
        }
        if (dto.getFechaLimite() != null) {
            if (creacion && dto.getFechaLimite().isBefore(LocalDate.now())) {
                throw new RuntimeException("La fecha límite no puede ser anterior a hoy.");
            }
            actividad.setFechaLimite(dto.getFechaLimite());
        } else if (creacion) {
            throw new RuntimeException("Las tareas requieren una fecha límite.");
        }
        if (dto.getRequiereDocumento() != null) {
            actividad.setRequiereDocumento(dto.getRequiereDocumento());
        }
        if (dto.getRequiereFotografia() != null) {
            actividad.setRequiereFotografia(dto.getRequiereFotografia());
        }
        if (dto.getRequiereCarta() != null) {
            actividad.setRequiereCarta(dto.getRequiereCarta());
        }
        if (dto.getOtrosRequisitos() != null) {
            actividad.setOtrosRequisitos(limpiar(dto.getOtrosRequisitos()));
        }
    }

    private static String requisitos(Actividad a) {
        return a.getRequiereDocumento() + "|" + a.getRequiereFotografia() + "|" + a.getRequiereCarta()
                + "|" + a.getOtrosRequisitos();
    }

    /**
     * Apadrinados que deben tener la actividad: toda la comunidad o los
     * seleccionados, que deben pertenecer a la comunidad de la actividad.
     */
    private List<Apadrinado> resolverDestinatarios(Actividad actividad, ActividadRequestDTO dto) {
        Long comunidadId = actividad.getComunidad().getId();
        if (Boolean.TRUE.equals(actividad.getAsignadaAComunidad())) {
            return apadrinadoRepository.findByComunidadId(comunidadId);
        }
        List<Long> ids = dto.getApadrinadoIds();
        if (ids == null || ids.isEmpty()) {
            throw new RuntimeException("Seleccione al menos un apadrinado o asigne la actividad a toda la comunidad.");
        }
        List<Apadrinado> seleccionados = apadrinadoRepository.findAllById(new LinkedHashSet<>(ids));
        if (seleccionados.size() != new LinkedHashSet<>(ids).size()) {
            throw new RuntimeException("Alguno de los apadrinados seleccionados no existe.");
        }
        for (Apadrinado ap : seleccionados) {
            if (ap.getComunidad() == null || !ap.getComunidad().getId().equals(comunidadId)) {
                throw new RuntimeException(ConvertidorDTO.nombre(ap) + " no pertenece a la comunidad de la actividad.");
            }
        }
        return seleccionados;
    }

    public static String etiqueta(TipoActividad tipo) {
        return switch (tipo) {
            case ANUNCIO -> "Anuncio";
            case MATERIAL_APOYO -> "Material de apoyo";
            default -> "Tarea";
        };
    }

    private static String obligatorio(String texto, String mensaje) {
        if (texto == null || texto.isBlank()) {
            throw new RuntimeException(mensaje);
        }
        return texto.trim();
    }

    private static String limpiar(String texto) {
        return texto == null || texto.isBlank() ? null : texto.trim();
    }
}
