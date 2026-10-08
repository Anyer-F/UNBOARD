package com.example.backend.service;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.dto.ActividadEstadoDTO;
import com.example.backend.dto.ActividadRequestDTO;
import com.example.backend.dto.ActividadResponseDTO;
import com.example.backend.dto.PagedResponseDTO;
import com.example.backend.entity.Actividad;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Coordinador;
import com.example.backend.entity.Documento;
import com.example.backend.entity.EstadoActividad;
import com.example.backend.entity.Usuario;
import com.example.backend.helper.PaginationHelper;
import com.example.backend.repository.ActividadRepository;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.CoordinadorRepository;
import com.example.backend.repository.DocumentoRepository;
import com.example.backend.repository.HistorialActividadRepository;
import com.example.backend.repository.UsuarioRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class ActividadService {

    private final ActividadRepository actividadRepository;
    private final CoordinadorRepository coordinadorRepository;
    private final ApadrinadoRepository apadrinadoRepository;
    private final UsuarioRepository usuarioRepository;
    private final DocumentoRepository documentoRepository;
    private final HistorialActividadRepository historialActividadRepository;
    private final FileStorageService fileStorageService;
    private final NotificacionService notificacionService;
    private final HistorialActividadService historialActividadService;

    @Transactional(readOnly = true)
    public List<ActividadResponseDTO> listarTodas() {
        return actividadRepository.findAll().stream()
                .map(this::convertirAResponseDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public ActividadResponseDTO obtenerPorId(Long id) {
        Actividad actividad = actividadRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Actividad no encontrada con ID: " + id));
        return convertirAResponseDTO(actividad);
    }

    @Transactional(readOnly = true)
    public List<ActividadResponseDTO> listarPorApadrinado(Long apadrinadoId, EstadoActividad estado) {
        List<Actividad> lista;
        if (estado != null) {
            lista = actividadRepository.findByApadrinadoIdAndEstado(apadrinadoId, estado);
        } else {
            lista = actividadRepository.findByApadrinadoId(apadrinadoId);
        }
        return lista.stream().map(this::convertirAResponseDTO).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<ActividadResponseDTO> listarPorCoordinador(Long coordinadorId, EstadoActividad estado) {
        List<Actividad> lista;
        if (estado != null) {
            lista = actividadRepository.findByCoordinadorIdAndEstado(coordinadorId, estado);
        } else {
            lista = actividadRepository.findByCoordinadorId(coordinadorId);
        }
        return lista.stream().map(this::convertirAResponseDTO).collect(Collectors.toList());
    }

    // ==================== MÉTODOS DE PAGINACIÓN ====================

    @Transactional(readOnly = true)
    public PagedResponseDTO<ActividadResponseDTO> listarTodasPaginado(int pagina, int tamano, String sortBy, String sortDir) {
        Sort sort = sortDir.equalsIgnoreCase("desc") ? Sort.by(sortBy).descending() : Sort.by(sortBy).ascending();
        Pageable pageable = PageRequest.of(pagina, tamano, sort);
        Page<Actividad> page = actividadRepository.findAll(pageable);
        return PaginationHelper.convertToPagedResponse(page, this::convertirAResponseDTO);
    }

    @Transactional(readOnly = true)
    public PagedResponseDTO<ActividadResponseDTO> listarPorApadrinadoPaginado(
            Long apadrinadoId, EstadoActividad estado, String titulo, int pagina, int tamano, String sortBy, String sortDir) {
        Sort sort = sortDir.equalsIgnoreCase("desc") ? Sort.by(sortBy).descending() : Sort.by(sortBy).ascending();
        Pageable pageable = PageRequest.of(pagina, tamano, sort);
        Page<Actividad> page;

        if (estado != null && titulo != null && !titulo.isEmpty()) {
            page = actividadRepository.findByApadrinadoIdAndEstadoAndTituloContainingIgnoreCase(apadrinadoId, estado, titulo, pageable);
        } else if (estado != null) {
            page = actividadRepository.findByApadrinadoIdAndEstado(apadrinadoId, estado, pageable);
        } else {
            page = actividadRepository.findByApadrinadoId(apadrinadoId, pageable);
        }

        return PaginationHelper.convertToPagedResponse(page, this::convertirAResponseDTO);
    }

    @Transactional(readOnly = true)
    public PagedResponseDTO<ActividadResponseDTO> listarPorCoordinadorPaginado(
            Long coordinadorId, EstadoActividad estado, String titulo, int pagina, int tamano, String sortBy, String sortDir) {
        Sort sort = sortDir.equalsIgnoreCase("desc") ? Sort.by(sortBy).descending() : Sort.by(sortBy).ascending();
        Pageable pageable = PageRequest.of(pagina, tamano, sort);
        Page<Actividad> page;

        if (estado != null && titulo != null && !titulo.isEmpty()) {
            page = actividadRepository.findByCoordinadorIdAndEstadoAndTituloContainingIgnoreCase(coordinadorId, estado, titulo, pageable);
        } else if (estado != null) {
            page = actividadRepository.findByCoordinadorIdAndEstado(coordinadorId, estado, pageable);
        } else {
            page = actividadRepository.findByCoordinadorId(coordinadorId, pageable);
        }

        return PaginationHelper.convertToPagedResponse(page, this::convertirAResponseDTO);
    }

    @Transactional(readOnly = true)
    public PagedResponseDTO<ActividadResponseDTO> listarPorEstadoPaginado(
            EstadoActividad estado, int pagina, int tamano, String sortBy, String sortDir) {
        Sort sort = sortDir.equalsIgnoreCase("desc") ? Sort.by(sortBy).descending() : Sort.by(sortBy).ascending();
        Pageable pageable = PageRequest.of(pagina, tamano, sort);
        Page<Actividad> page = actividadRepository.findByEstado(estado, pageable);
        return PaginationHelper.convertToPagedResponse(page, this::convertirAResponseDTO);
    }

    @Transactional
    public ActividadResponseDTO crear(ActividadRequestDTO dto) {
        Coordinador coordinador = null;
        if (dto.getCoordinadorId() != null) {
            coordinador = coordinadorRepository.findById(dto.getCoordinadorId())
                    .orElseThrow(() -> new RuntimeException("Coordinador no encontrado con ID: " + dto.getCoordinadorId()));
        }

        Apadrinado apadrinado = null;
        if (dto.getApadrinadoId() != null) {
            apadrinado = apadrinadoRepository.findById(dto.getApadrinadoId())
                    .orElseThrow(() -> new RuntimeException("Apadrinado no encontrado con ID: " + dto.getApadrinadoId()));
        }

        Actividad actividad = Actividad.builder()
                .titulo(dto.getTitulo())
                .descripcion(dto.getDescripcion())
                .fechaCreacion(LocalDate.now())
                .fechaLimite(dto.getFechaLimite())
                .requiereDocumento(dto.getRequiereDocumento() != null ? dto.getRequiereDocumento() : false)
                .requiereFotografia(dto.getRequiereFotografia() != null ? dto.getRequiereFotografia() : false)
                .estado(EstadoActividad.PENDIENTE)
                .coordinador(coordinador)
                .apadrinado(apadrinado)
                .build();

        Actividad guardada = actividadRepository.save(actividad);

        // Registro de historial inicial
        Usuario creador = coordinador != null ? coordinador.getUsuario() : null;
        historialActividadService.registrarCambio(
                guardada,
                null,
                EstadoActividad.PENDIENTE,
                "CREACIÓN",
                "Actividad asignada: " + guardada.getTitulo(),
                creador
        );

        // Notificación automática al apadrinado
        if (guardada.getApadrinado() != null && guardada.getApadrinado().getUsuario() != null) {
            notificacionService.notificar(
                    guardada.getApadrinado().getUsuario(),
                    "Nueva actividad asignada",
                    "Se te ha asignado la actividad: '" + guardada.getTitulo() + "'" + (guardada.getFechaLimite() != null ? ". Fecha límite: " + guardada.getFechaLimite() : ""),
                    com.example.backend.entity.TipoNotificacion.NUEVA_ACTIVIDAD,
                    guardada.getId(),
                    "ACTIVIDAD"
            );
        }

        return convertirAResponseDTO(guardada);
    }

    @Transactional
    public List<ActividadResponseDTO> crearMasiva(ActividadRequestDTO dto) {
        Coordinador coordinador = null;
        if (dto.getCoordinadorId() != null) {
            coordinador = coordinadorRepository.findById(dto.getCoordinadorId())
                    .orElseThrow(() -> new RuntimeException("Coordinador no encontrado con ID: " + dto.getCoordinadorId()));
        }

        List<Apadrinado> apadrinados;
        if (dto.getApadrinadoIds() != null && !dto.getApadrinadoIds().isEmpty()) {
            apadrinados = apadrinadoRepository.findAllById(dto.getApadrinadoIds());
        } else if (dto.getCoordinadorId() != null) {
            // Asignar a todos los apadrinados del coordinador
            apadrinados = apadrinadoRepository.findByCoordinadorId(dto.getCoordinadorId());
        } else {
            apadrinados = apadrinadoRepository.findAll();
        }

        Usuario creador = coordinador != null ? coordinador.getUsuario() : null;
        List<ActividadResponseDTO> creadas = new ArrayList<>();
        for (Apadrinado ap : apadrinados) {
            Actividad actividad = Actividad.builder()
                    .titulo(dto.getTitulo())
                    .descripcion(dto.getDescripcion())
                    .fechaCreacion(LocalDate.now())
                    .fechaLimite(dto.getFechaLimite())
                    .requiereDocumento(dto.getRequiereDocumento() != null ? dto.getRequiereDocumento() : false)
                    .requiereFotografia(dto.getRequiereFotografia() != null ? dto.getRequiereFotografia() : false)
                    .estado(EstadoActividad.PENDIENTE)
                    .coordinador(coordinador)
                    .apadrinado(ap)
                    .build();

            Actividad guardada = actividadRepository.save(actividad);

            // Registro de historial inicial
            historialActividadService.registrarCambio(
                    guardada,
                    null,
                    EstadoActividad.PENDIENTE,
                    "CREACIÓN",
                    "Asignación masiva a apadrinado",
                    creador
            );

            // Notificar a cada apadrinado
            if (ap.getUsuario() != null) {
                notificacionService.notificar(
                        ap.getUsuario(),
                        "Nueva actividad asignada",
                        "Se te ha asignado la actividad: '" + guardada.getTitulo() + "'",
                        com.example.backend.entity.TipoNotificacion.NUEVA_ACTIVIDAD,
                        guardada.getId(),
                        "ACTIVIDAD"
                );
            }

            creadas.add(convertirAResponseDTO(guardada));
        }

        return creadas;
    }

    @Transactional
    public ActividadResponseDTO actualizar(Long id, ActividadRequestDTO dto) {
        Actividad actividad = actividadRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Actividad no encontrada con ID: " + id));

        if (dto.getTitulo() != null) {
            actividad.setTitulo(dto.getTitulo());
        }
        if (dto.getDescripcion() != null) {
            actividad.setDescripcion(dto.getDescripcion());
        }
        if (dto.getFechaLimite() != null) {
            actividad.setFechaLimite(dto.getFechaLimite());
        }
        if (dto.getRequiereDocumento() != null) {
            actividad.setRequiereDocumento(dto.getRequiereDocumento());
        }
        if (dto.getRequiereFotografia() != null) {
            actividad.setRequiereFotografia(dto.getRequiereFotografia());
        }

        Actividad actualizada = actividadRepository.save(actividad);

        // Registro de auditoría por edición
        Usuario usuarioModificador = null;
        try {
            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.isAuthenticated() && !auth.getName().equals("anonymousUser")) {
                usuarioModificador = usuarioRepository.findByCorreo(auth.getName()).orElse(null);
            }
        } catch (Exception ignored) {}
        if (usuarioModificador == null && actividad.getCoordinador() != null) {
            usuarioModificador = actividad.getCoordinador().getUsuario();
        }

        historialActividadService.registrarCambio(
                actualizada,
                actualizada.getEstado(),
                actualizada.getEstado(),
                "EDICIÓN",
                "Actualización de parámetros de la actividad",
                usuarioModificador
        );

        return convertirAResponseDTO(actualizada);
    }

    @Transactional
    public ActividadResponseDTO cambiarEstado(Long id, ActividadEstadoDTO dto) {
        Actividad actividad = actividadRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Actividad no encontrada con ID: " + id));

        EstadoActividad estadoAnterior = actividad.getEstado();

        // FASE E: validaciones de transición para EN_REVISIÓN y VENCIDO
        if (dto.getEstado() == EstadoActividad.EN_REVISION
                && estadoAnterior != EstadoActividad.ENTREGADA) {
            throw new RuntimeException(
                    "Solo se puede iniciar la revisión de una actividad entregada. Estado actual: "
                    + estadoAnterior);
        }
        if (dto.getEstado() == EstadoActividad.VENCIDO) {
            throw new RuntimeException(
                    "El estado VENCIDO se asigna automáticamente al vencer la fecha límite.");
        }

        if (dto.getEstado() != null) {
            actividad.setEstado(dto.getEstado());
        }
        if (dto.getObservaciones() != null) {
            actividad.setObservaciones(dto.getObservaciones());
        }

        Actividad actualizada = actividadRepository.save(actividad);

        // Obtener el usuario modificador (coordinador o admin)
        Usuario usuarioModificador = null;
        try {
            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.isAuthenticated() && !auth.getName().equals("anonymousUser")) {
                usuarioModificador = usuarioRepository.findByCorreo(auth.getName()).orElse(null);
            }
        } catch (Exception ignored) {}
        if (usuarioModificador == null && actividad.getCoordinador() != null) {
            usuarioModificador = actividad.getCoordinador().getUsuario();
        }

        String accion;
        if (dto.getEstado() == EstadoActividad.APROBADA) {
            accion = "APROBACIÓN";
        } else if (dto.getEstado() == EstadoActividad.CORRECCION_SOLICITADA) {
            accion = "CORRECCIÓN SOLICITADA";
        } else if (dto.getEstado() == EstadoActividad.ENTREGADA) {
            accion = "ENTREGA REGISTRADA";
        } else if (dto.getEstado() == EstadoActividad.EN_REVISION) {
            accion = "REVISIÓN INICIADA";
        } else if (dto.getEstado() == EstadoActividad.VENCIDO) {
            accion = "VENCIMIENTO";
        } else {
            accion = "CAMBIO DE ESTADO";
        }

        historialActividadService.registrarCambio(
                actualizada,
                estadoAnterior,
                dto.getEstado() != null ? dto.getEstado() : estadoAnterior,
                accion,
                dto.getObservaciones(),
                usuarioModificador
        );

        // Notificaciones automáticas según el nuevo estado
        if (actividad.getApadrinado() != null && actividad.getApadrinado().getUsuario() != null) {
            Usuario usuarioAp = actividad.getApadrinado().getUsuario();

            if (dto.getEstado() == EstadoActividad.APROBADA) {
                notificacionService.notificar(
                        usuarioAp,
                        "¡Actividad Aprobada!",
                        "Tu entrega para la actividad '" + actividad.getTitulo() + "' ha sido revisada y APROBADA satisfactoriamente.",
                        com.example.backend.entity.TipoNotificacion.ACTIVIDAD_APROBADA,
                        actividad.getId(),
                        "ACTIVIDAD"
                );
            } else if (dto.getEstado() == EstadoActividad.CORRECCION_SOLICITADA) {
                String obs = (dto.getObservaciones() != null && !dto.getObservaciones().isBlank())
                        ? " Observaciones: " + dto.getObservaciones()
                        : " Por favor revisa los requerimientos e intenta de nuevo.";
                notificacionService.notificar(
                        usuarioAp,
                        "Corrección Solicitada",
                        "Se solicitan correcciones en tu entrega para la actividad '" + actividad.getTitulo() + "'." + obs,
                        com.example.backend.entity.TipoNotificacion.CORRECCION_SOLICITADA,
                        actividad.getId(),
                        "ACTIVIDAD"
                );
            } else if (dto.getEstado() == EstadoActividad.EN_REVISION) {
                notificacionService.notificar(
                        usuarioAp,
                        "Documento en revisión",
                        "Tu entrega para la actividad '" + actividad.getTitulo()
                                + "' está siendo revisada por el coordinador.",
                        com.example.backend.entity.TipoNotificacion.ACTIVIDAD_EN_REVISION,
                        actividad.getId(),
                        "ACTIVIDAD"
                );
            }
        }

        return convertirAResponseDTO(actualizada);
    }

    // ==================== FASE E: ESTADOS EN_REVISIÓN Y VENCIDO ====================

    /**
     * Marca como VENCIDO una actividad cuya fecha límite ya pasó
     * y que aún no fue entregada ni aprobada.
     */
    @Transactional
    public ActividadResponseDTO marcarVencido(Long id) {
        Actividad actividad = actividadRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Actividad no encontrada con ID: " + id));

        if (actividad.getEstado() == EstadoActividad.VENCIDO) {
            return convertirAResponseDTO(actividad);
        }
        if (actividad.getEstado() != EstadoActividad.PENDIENTE
                && actividad.getEstado() != EstadoActividad.EN_PROCESO) {
            throw new RuntimeException(
                    "Solo las actividades pendientes o en progreso pueden marcarse como vencidas. Estado actual: "
                    + actividad.getEstado());
        }
        if (actividad.getFechaLimite() == null || !actividad.getFechaLimite().isBefore(LocalDate.now())) {
            throw new RuntimeException(
                    "La actividad aún no ha vencido. Fecha límite: " + actividad.getFechaLimite());
        }

        marcarVencida(actividad, obtenerUsuarioAutenticado());
        return convertirAResponseDTO(actividad);
    }

    /**
     * Marca como VENCIDO todas las actividades pendientes o en progreso
     * del coordinador indicado cuya fecha límite ya pasó.
     */
    @Transactional
    public List<ActividadResponseDTO> marcarVencidasDelCoordinador(Long coordinadorId) {
        LocalDate hoy = LocalDate.now();
        List<Actividad> candidatas = actividadRepository.findByCoordinadorIdAndEstadoIn(
                coordinadorId, List.of(EstadoActividad.PENDIENTE, EstadoActividad.EN_PROCESO));

        Usuario modificador = obtenerUsuarioAutenticado();
        List<ActividadResponseDTO> marcadas = new ArrayList<>();
        for (Actividad actividad : candidatas) {
            if (actividad.getFechaLimite() != null && actividad.getFechaLimite().isBefore(hoy)) {
                marcarVencida(actividad, modificador);
                marcadas.add(convertirAResponseDTO(actividad));
            }
        }
        return marcadas;
    }

    /**
     * Marca como VENCIDO todas las actividades pendientes o en progreso
     * de todo el sistema cuya fecha límite ya pasó (tarea programada).
     */
    @Transactional
    public int marcarVencidasGlobal() {
        LocalDate hoy = LocalDate.now();
        List<Actividad> candidatas = actividadRepository.findByEstadoIn(
                List.of(EstadoActividad.PENDIENTE, EstadoActividad.EN_PROCESO));

        int marcadas = 0;
        for (Actividad actividad : candidatas) {
            if (actividad.getFechaLimite() != null && actividad.getFechaLimite().isBefore(hoy)) {
                marcarVencida(actividad, null);
                marcadas++;
            }
        }
        return marcadas;
    }

    /**
     * Aplica el estado VENCIDO a una actividad candidata, con historial
     * de auditoría y notificación al apadrinado.
     */
    private void marcarVencida(Actividad actividad, Usuario usuarioModificador) {
        EstadoActividad estadoAnterior = actividad.getEstado();
        actividad.setEstado(EstadoActividad.VENCIDO);
        actividadRepository.save(actividad);

        historialActividadService.registrarCambio(
                actividad,
                estadoAnterior,
                EstadoActividad.VENCIDO,
                "VENCIMIENTO",
                "La actividad venció el " + actividad.getFechaLimite()
                        + " sin entrega registrada.",
                usuarioModificador
        );

        if (actividad.getApadrinado() != null && actividad.getApadrinado().getUsuario() != null) {
            notificacionService.notificar(
                    actividad.getApadrinado().getUsuario(),
                    "Actividad vencida",
                    "La actividad '" + actividad.getTitulo() + "' venció el "
                            + actividad.getFechaLimite() + " y no fue entregada a tiempo.",
                    com.example.backend.entity.TipoNotificacion.ACTIVIDAD_VENCIDA,
                    actividad.getId(),
                    "ACTIVIDAD"
            );
        }
    }

    /**
     * Obtiene el usuario autenticado en el contexto de seguridad, si lo hay.
     */
    private Usuario obtenerUsuarioAutenticado() {
        try {
            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.isAuthenticated() && !auth.getName().equals("anonymousUser")) {
                return usuarioRepository.findByCorreo(auth.getName()).orElse(null);
            }
        } catch (Exception ignored) {}
        return null;
    }

    @Transactional
    public void eliminar(Long id) {
        Actividad actividad = actividadRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Actividad no encontrada con ID: " + id));

        // 1. Eliminar documentos físicos y registros asociados a la actividad
        List<Documento> docs = documentoRepository.findByActividadId(id);
        for (Documento doc : docs) {
            try {
                fileStorageService.deleteFile(doc.getNombreAlmacenado());
            } catch (Exception ignored) {}
            documentoRepository.delete(doc);
        }

        // 2. Eliminar historial de auditoría asociado a la actividad
        historialActividadRepository.deleteByActividadId(id);

        // 3. Eliminar la actividad
        actividadRepository.delete(actividad);
    }

    public ActividadResponseDTO convertirAResponseDTO(Actividad actividad) {
        String coordNombre = null;
        Long coordId = null;
        if (actividad.getCoordinador() != null) {
            coordId = actividad.getCoordinador().getId();
            if (actividad.getCoordinador().getUsuario() != null) {
                coordNombre = actividad.getCoordinador().getUsuario().getNombre();
            }
        }

        String apadrinadoNombre = null;
        Long apadrinadoId = null;
        if (actividad.getApadrinado() != null) {
            apadrinadoId = actividad.getApadrinado().getId();
            if (actividad.getApadrinado().getUsuario() != null) {
                apadrinadoNombre = actividad.getApadrinado().getUsuario().getNombre();
            }
        }

        return ActividadResponseDTO.builder()
                .id(actividad.getId())
                .titulo(actividad.getTitulo())
                .descripcion(actividad.getDescripcion())
                .fechaCreacion(actividad.getFechaCreacion())
                .fechaLimite(actividad.getFechaLimite())
                .requiereDocumento(actividad.getRequiereDocumento())
                .requiereFotografia(actividad.getRequiereFotografia())
                .estado(actividad.getEstado())
                .observaciones(actividad.getObservaciones())
                .coordinadorId(coordId)
                .coordinadorNombre(coordNombre)
                .apadrinadoId(apadrinadoId)
                .apadrinadoNombre(apadrinadoNombre)
                .build();
    }
}
