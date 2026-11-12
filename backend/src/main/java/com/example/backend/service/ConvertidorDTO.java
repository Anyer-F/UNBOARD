package com.example.backend.service;

import java.time.LocalDate;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Component;

import com.example.backend.dto.ActividadResponseDTO;
import com.example.backend.dto.ApadrinadoResponseDTO;
import com.example.backend.dto.AsignacionResponseDTO;
import com.example.backend.dto.CartaResponseDTO;
import com.example.backend.dto.DocumentoResponseDTO;
import com.example.backend.dto.EntregaResponseDTO;
import com.example.backend.dto.HistorialActividadResponseDTO;
import com.example.backend.dto.ModuloResponseDTO;
import com.example.backend.dto.ObservacionResponseDTO;
import com.example.backend.dto.ResumenAvanceDTO;
import com.example.backend.dto.SugerenciaResponseDTO;
import com.example.backend.entity.Actividad;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Asignacion;
import com.example.backend.entity.Carta;
import com.example.backend.entity.Documento;
import com.example.backend.entity.Entrega;
import com.example.backend.entity.EstadoActividad;
import com.example.backend.entity.HistorialActividad;
import com.example.backend.entity.Modulo;
import com.example.backend.entity.Observacion;
import com.example.backend.entity.OrigenDocumento;
import com.example.backend.entity.Sugerencia;
import com.example.backend.entity.TipoActividad;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ActividadRepository;
import com.example.backend.repository.AsignacionRepository;
import com.example.backend.repository.CartaRepository;
import com.example.backend.repository.DocumentoRepository;
import com.example.backend.repository.EntregaRepository;
import com.example.backend.repository.SugerenciaRepository;

import lombok.RequiredArgsConstructor;

/**
 * Conversión de entidades a DTOs, compartida por los servicios.
 */
@Component
@RequiredArgsConstructor
public class ConvertidorDTO {

    /** Días antes de la fecha límite en que una tarea se considera próxima a vencer. */
    public static final int DIAS_PROXIMA_A_VENCER = 3;

    private final DocumentoRepository documentoRepository;
    private final CartaRepository cartaRepository;
    private final SugerenciaRepository sugerenciaRepository;
    private final EntregaRepository entregaRepository;
    private final AsignacionRepository asignacionRepository;
    private final ActividadRepository actividadRepository;

    public static String nombreCompleto(Usuario u) {
        if (u == null) {
            return null;
        }
        String nombre = u.getNombre() != null ? u.getNombre().trim() : "";
        if (u.getApellido() != null && !u.getApellido().isBlank()) {
            nombre = (nombre + " " + u.getApellido().trim()).trim();
        }
        return nombre.isEmpty() ? u.getCorreo() : nombre;
    }

    public static String nombre(Apadrinado a) {
        return a != null ? nombreCompleto(a.getUsuario()) : null;
    }

    // ==================== ACTIVIDADES ====================

    /**
     * @param conAdjuntos incluye el material subido por el coordinador
     * @param conResumen  incluye el avance por estado (para el coordinador)
     */
    public ActividadResponseDTO actividad(Actividad a, boolean conAdjuntos, boolean conResumen) {
        if (a == null) {
            return null;
        }
        List<DocumentoResponseDTO> adjuntos = null;
        if (conAdjuntos) {
            adjuntos = documentoRepository.findByActividadIdAndOrigen(a.getId(), OrigenDocumento.COORDINADOR)
                    .stream().map(this::documento).collect(Collectors.toList());
        }
        ResumenAvanceDTO resumen = null;
        if (conResumen) {
            resumen = resumen(asignacionRepository.findByActividadIdOrderByApadrinadoUsuarioNombreAsc(a.getId()));
        }
        return ActividadResponseDTO.builder()
                .id(a.getId())
                .tipo(a.getTipo())
                .titulo(a.getTitulo())
                .descripcion(a.getDescripcion())
                .instrucciones(a.getInstrucciones())
                .fechaCreacion(a.getFechaCreacion())
                .fechaActualizacion(a.getFechaActualizacion())
                .fechaLimite(a.getFechaLimite())
                .requiereDocumento(a.getRequiereDocumento())
                .requiereFotografia(a.getRequiereFotografia())
                .requiereCarta(a.getRequiereCarta())
                .otrosRequisitos(a.getOtrosRequisitos())
                .comunidadId(a.getComunidad() != null ? a.getComunidad().getId() : null)
                .comunidadNombre(a.getComunidad() != null ? a.getComunidad().getNombre() : null)
                .moduloId(a.getModulo() != null ? a.getModulo().getId() : null)
                .moduloNombre(a.getModulo() != null ? a.getModulo().getNombre() : null)
                .coordinadorId(a.getCoordinador() != null ? a.getCoordinador().getId() : null)
                .coordinadorNombre(a.getCoordinador() != null ? nombreCompleto(a.getCoordinador().getUsuario()) : null)
                .asignadaAComunidad(a.getAsignadaAComunidad())
                .eliminada(a.getEliminada())
                .adjuntos(adjuntos)
                .resumen(resumen)
                .build();
    }

    public ResumenAvanceDTO resumen(List<Asignacion> asignaciones) {
        Map<EstadoActividad, Long> conteo = asignaciones.stream()
                .collect(Collectors.groupingBy(Asignacion::getEstado, Collectors.counting()));
        Function<EstadoActividad, Long> c = e -> conteo.getOrDefault(e, 0L);
        return ResumenAvanceDTO.builder()
                .asignados(asignaciones.size())
                .pendientes(c.apply(EstadoActividad.PENDIENTE))
                .enProgreso(c.apply(EstadoActividad.EN_PROGRESO))
                .enviados(c.apply(EstadoActividad.ENVIADO))
                .enRevision(c.apply(EstadoActividad.EN_REVISION))
                .correcciones(c.apply(EstadoActividad.CORRECCION_SOLICITADA))
                .aprobados(c.apply(EstadoActividad.APROBADO))
                .vencidos(c.apply(EstadoActividad.VENCIDO))
                .publicados(c.apply(EstadoActividad.PUBLICADO))
                .vistos(c.apply(EstadoActividad.VISTO))
                .build();
    }

    public ModuloResponseDTO modulo(Modulo m) {
        if (m == null) {
            return null;
        }
        return ModuloResponseDTO.builder()
                .id(m.getId())
                .comunidadId(m.getComunidad() != null ? m.getComunidad().getId() : null)
                .nombre(m.getNombre())
                .descripcion(m.getDescripcion())
                .orden(m.getOrden())
                .totalActividades(actividadRepository.countByModuloIdAndEliminadaFalse(m.getId()))
                .fechaCreacion(m.getFechaCreacion())
                .build();
    }

    // ==================== ASIGNACIONES Y ENTREGAS ====================

    public AsignacionResponseDTO asignacion(Asignacion s, boolean conActividad) {
        if (s == null) {
            return null;
        }
        Actividad a = s.getActividad();
        Entrega ultima = entregaRepository.findFirstByAsignacionIdOrderByVersionDesc(s.getId()).orElse(null);
        String ultimaSugerencia = null;
        if (ultima != null) {
            List<Sugerencia> sugerencias = sugerenciaRepository.findByEntregaAsignacionIdOrderByFechaAsc(s.getId());
            if (!sugerencias.isEmpty()) {
                ultimaSugerencia = sugerencias.get(sugerencias.size() - 1).getTexto();
            }
        }
        return AsignacionResponseDTO.builder()
                .id(s.getId())
                .actividadId(a != null ? a.getId() : null)
                .apadrinadoId(s.getApadrinado() != null ? s.getApadrinado().getId() : null)
                .apadrinadoNombre(nombre(s.getApadrinado()))
                .estado(s.getEstado())
                .fechaAsignacion(s.getFechaAsignacion())
                .fechaInicio(s.getFechaInicio())
                .fechaEnvio(s.getFechaEnvio())
                .fechaAprobacion(s.getFechaAprobacion())
                .fechaVisto(s.getFechaVisto())
                .versionActual(ultima != null ? ultima.getVersion() : null)
                .ultimaSugerencia(ultimaSugerencia)
                .proximaAVencer(proximaAVencer(s))
                .actividad(conActividad ? actividad(a, false, false) : null)
                .build();
    }

    public static boolean proximaAVencer(Asignacion s) {
        Actividad a = s.getActividad();
        if (a == null || a.getTipo() != TipoActividad.TAREA || a.getFechaLimite() == null) {
            return false;
        }
        if (s.getEstado() != EstadoActividad.PENDIENTE && s.getEstado() != EstadoActividad.EN_PROGRESO
                && s.getEstado() != EstadoActividad.CORRECCION_SOLICITADA) {
            return false;
        }
        LocalDate hoy = LocalDate.now();
        return !a.getFechaLimite().isBefore(hoy)
                && !a.getFechaLimite().isAfter(hoy.plusDays(DIAS_PROXIMA_A_VENCER));
    }

    public EntregaResponseDTO entrega(Entrega e) {
        return EntregaResponseDTO.builder()
                .id(e.getId())
                .asignacionId(e.getAsignacion() != null ? e.getAsignacion().getId() : null)
                .version(e.getVersion())
                .estado(e.getEstado())
                .comentario(e.getComentario())
                .fechaCreacion(e.getFechaCreacion())
                .fechaEnvio(e.getFechaEnvio())
                .fechaRevision(e.getFechaRevision())
                .revisorNombre(nombreCompleto(e.getRevisor()))
                .documentos(documentoRepository.findByEntregaId(e.getId()).stream()
                        .map(this::documento).collect(Collectors.toList()))
                .cartas(cartaRepository.findByEntregaId(e.getId()).stream()
                        .map(this::carta).collect(Collectors.toList()))
                .sugerencias(sugerenciaRepository.findByEntregaIdOrderByFechaAsc(e.getId()).stream()
                        .map(this::sugerencia).collect(Collectors.toList()))
                .build();
    }

    public SugerenciaResponseDTO sugerencia(Sugerencia s) {
        return SugerenciaResponseDTO.builder()
                .id(s.getId())
                .entregaId(s.getEntrega() != null ? s.getEntrega().getId() : null)
                .version(s.getEntrega() != null ? s.getEntrega().getVersion() : null)
                .texto(s.getTexto())
                .autorNombre(nombreCompleto(s.getAutor()))
                .fecha(s.getFecha())
                .build();
    }

    public ObservacionResponseDTO observacion(Observacion o) {
        return ObservacionResponseDTO.builder()
                .id(o.getId())
                .expedienteId(o.getExpediente() != null ? o.getExpediente().getId() : null)
                .asignacionId(o.getAsignacion() != null ? o.getAsignacion().getId() : null)
                .actividadTitulo(o.getAsignacion() != null && o.getAsignacion().getActividad() != null
                        ? o.getAsignacion().getActividad().getTitulo() : null)
                .texto(o.getTexto())
                .autorNombre(nombreCompleto(o.getAutor()))
                .fecha(o.getFecha())
                .build();
    }

    // ==================== DOCUMENTOS Y CARTAS ====================

    public DocumentoResponseDTO documento(Documento d) {
        Long apadrinadoId = null;
        String apadrinadoNombre = null;
        if (d.getExpediente() != null && d.getExpediente().getApadrinado() != null) {
            apadrinadoId = d.getExpediente().getApadrinado().getId();
            apadrinadoNombre = nombre(d.getExpediente().getApadrinado());
        }
        String estado;
        if (d.getOrigen() == OrigenDocumento.COORDINADOR) {
            estado = "PUBLICADO";
        } else if (d.getEntrega() != null) {
            estado = d.getEntrega().getEstado().name();
        } else {
            estado = "SIN_ENTREGA";
        }
        return DocumentoResponseDTO.builder()
                .id(d.getId())
                .nombreOriginal(d.getNombreOriginal())
                .nombreAlmacenado(d.getNombreAlmacenado())
                .urlDescarga("/api/documentos/" + d.getId() + "/descargar")
                .tipoMime(d.getTipoMime())
                .tamanioBytes(d.getTamanioBytes())
                .fechaSubida(d.getFechaSubida())
                .tipoDocumento(d.getTipoDocumento())
                .descripcion(d.getDescripcion())
                .origen(d.getOrigen())
                .estado(estado)
                .expedienteId(d.getExpediente() != null ? d.getExpediente().getId() : null)
                .apadrinadoId(apadrinadoId)
                .apadrinadoNombre(apadrinadoNombre)
                .actividadId(d.getActividad() != null ? d.getActividad().getId() : null)
                .actividadTitulo(d.getActividad() != null ? d.getActividad().getTitulo() : null)
                .entregaId(d.getEntrega() != null ? d.getEntrega().getId() : null)
                .version(d.getEntrega() != null ? d.getEntrega().getVersion() : null)
                .subidoPorUsuarioId(d.getSubidoPor() != null ? d.getSubidoPor().getId() : null)
                .subidoPorNombre(nombreCompleto(d.getSubidoPor()))
                .build();
    }

    public CartaResponseDTO carta(Carta c) {
        return CartaResponseDTO.builder()
                .id(c.getId())
                .titulo(c.getTitulo())
                .contenido(c.getContenido())
                .fechaCreacion(c.getFechaCreacion())
                .fechaEnvio(c.getFechaEnvio())
                .tipoCarta(c.getTipoCarta())
                .estado(c.getEstado())
                .expedienteId(c.getExpediente() != null ? c.getExpediente().getId() : null)
                .actividadId(c.getActividad() != null ? c.getActividad().getId() : null)
                .actividadTitulo(c.getActividad() != null ? c.getActividad().getTitulo() : null)
                .entregaId(c.getEntrega() != null ? c.getEntrega().getId() : null)
                .version(c.getEntrega() != null ? c.getEntrega().getVersion() : null)
                .apadrinadoId(c.getApadrinado() != null ? c.getApadrinado().getId() : null)
                .apadrinadoNombre(nombre(c.getApadrinado()))
                .escritoPorId(c.getEscritoPor() != null ? c.getEscritoPor().getId() : null)
                .escritoPorNombre(nombreCompleto(c.getEscritoPor()))
                .build();
    }

    // ==================== PERSONAS E HISTORIAL ====================

    public ApadrinadoResponseDTO apadrinado(Apadrinado a) {
        if (a == null) {
            return null;
        }
        Usuario u = a.getUsuario();
        return ApadrinadoResponseDTO.builder()
                .id(a.getId())
                .usuarioId(u != null ? u.getId() : null)
                .nombre(u != null ? u.getNombre() : null)
                .apellido(u != null ? u.getApellido() : null)
                .correo(u != null ? u.getCorreo() : null)
                .telefono(u != null ? u.getTelefono() : null)
                .direccion(u != null ? u.getDireccion() : null)
                .fechaNacimiento(u != null ? u.getFechaNacimiento() : null)
                .coordinadorId(a.getCoordinador() != null ? a.getCoordinador().getId() : null)
                .coordinadorNombre(a.getCoordinador() != null ? nombreCompleto(a.getCoordinador().getUsuario()) : null)
                .comunidadId(a.getComunidad() != null ? a.getComunidad().getId() : null)
                .comunidadNombre(a.getComunidad() != null ? a.getComunidad().getNombre() : null)
                .build();
    }

    public HistorialActividadResponseDTO historial(HistorialActividad h) {
        Usuario u = h.getModificadoPor();
        return HistorialActividadResponseDTO.builder()
                .id(h.getId())
                .entidad(h.getEntidad())
                .idEntidad(h.getIdEntidad())
                .referencia(h.getReferencia())
                .actividadId(h.getActividad() != null ? h.getActividad().getId() : null)
                .actividadTitulo(h.getActividad() != null ? h.getActividad().getTitulo() : h.getReferencia())
                .asignacionId(h.getAsignacion() != null ? h.getAsignacion().getId() : null)
                .apadrinadoId(h.getApadrinado() != null ? h.getApadrinado().getId() : null)
                .apadrinadoNombre(nombre(h.getApadrinado()))
                .comunidadId(h.getComunidad() != null ? h.getComunidad().getId() : null)
                .estadoAnterior(h.getEstadoAnterior())
                .estadoNuevo(h.getEstadoNuevo())
                .accion(h.getAccion())
                .observaciones(h.getObservaciones())
                .modificadoPorUsuarioId(u != null ? u.getId() : null)
                .modificadoPorNombre(nombreCompleto(u))
                .modificadoPorRol(u != null && u.getRol() != null ? u.getRol().getNombre() : null)
                .fechaHora(h.getFechaHora())
                .build();
    }

    public static <T> List<T> vacioSiNulo(List<T> lista) {
        return lista != null ? lista : Collections.emptyList();
    }
}
