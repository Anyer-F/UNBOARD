package com.example.backend.service;

import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.Optional;
import java.util.Set;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.config.AccesoDenegadoException;
import com.example.backend.entity.Actividad;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Asignacion;
import com.example.backend.entity.Carta;
import com.example.backend.entity.Comunidad;
import com.example.backend.entity.Coordinador;
import com.example.backend.entity.Documento;
import com.example.backend.entity.Expediente;
import com.example.backend.entity.OrigenDocumento;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ActividadRepository;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.AsignacionRepository;
import com.example.backend.repository.CartaRepository;
import com.example.backend.repository.CoordinadorRepository;
import com.example.backend.repository.DocumentoRepository;
import com.example.backend.repository.ExpedienteRepository;
import com.example.backend.repository.UsuarioRepository;

import lombok.RequiredArgsConstructor;

/**
 * Servicio central de autorización (RBAC y control de pertenencia).
 *
 * El control no se limita a la interfaz móvil: cada operación protegida
 * valida aquí la identidad, el rol y la pertenencia.
 *
 * - Coordinador: accede solo a las comunidades bajo su responsabilidad
 *   (principal + asociadas) y a sus apadrinados, actividades y expedientes.
 * - Apadrinado: accede solo a su comunidad, a las actividades que le fueron
 *   asignadas y a sus propias entregas. No tiene acceso a expedientes,
 *   PDF ni ZIP.
 * - Cualquier otro perfil no tiene acceso a funciones operativas.
 */
@Service
@RequiredArgsConstructor
public class SeguridadService {

    private final UsuarioRepository usuarioRepository;
    private final ApadrinadoRepository apadrinadoRepository;
    private final CoordinadorRepository coordinadorRepository;
    private final ActividadRepository actividadRepository;
    private final AsignacionRepository asignacionRepository;
    private final CartaRepository cartaRepository;
    private final DocumentoRepository documentoRepository;
    private final ExpedienteRepository expedienteRepository;

    // ==================== USUARIO ACTUAL ====================

    @Transactional(readOnly = true)
    public Usuario usuarioActual() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()
                || "anonymousUser".equals(auth.getName())) {
            throw new AccesoDenegadoException("No autenticado.");
        }
        return usuarioRepository.findByCorreo(auth.getName())
                .orElseThrow(() -> new AccesoDenegadoException("Usuario no encontrado."));
    }

    public boolean esCoordinador(Usuario usuario) {
        return usuario != null && usuario.getRol() != null
                && "COORDINADOR".equalsIgnoreCase(usuario.getRol().getNombre());
    }

    public boolean esApadrinado(Usuario usuario) {
        return usuario != null && usuario.getRol() != null
                && "APADRINADO".equalsIgnoreCase(usuario.getRol().getNombre());
    }

    @Transactional(readOnly = true)
    public Coordinador coordinadorActual() {
        Usuario usuario = usuarioActual();
        if (!esCoordinador(usuario)) {
            return null;
        }
        return coordinadorRepository.findByUsuarioId(usuario.getId()).orElse(null);
    }

    @Transactional(readOnly = true)
    public Apadrinado apadrinadoActual() {
        Usuario usuario = usuarioActual();
        if (!esApadrinado(usuario)) {
            return null;
        }
        return apadrinadoRepository.findByUsuarioId(usuario.getId()).orElse(null);
    }

    public void requerirCoordinador() {
        Usuario usuario = usuarioActual();
        if (!esCoordinador(usuario)) {
            throw new AccesoDenegadoException(
                    "Esta función es exclusiva del rol Coordinador.");
        }
    }

    /** Coordinador actual con perfil de coordinador (o 403). */
    @Transactional(readOnly = true)
    public Coordinador requerirCoordinadorActual() {
        requerirCoordinador();
        Coordinador coordinador = coordinadorActual();
        if (coordinador == null) {
            throw new AccesoDenegadoException("No tiene un perfil de coordinador.");
        }
        return coordinador;
    }

    /** Apadrinado actual incorporado a una comunidad (o 403). */
    @Transactional(readOnly = true)
    public Apadrinado requerirApadrinadoActual() {
        Usuario usuario = usuarioActual();
        if (!esApadrinado(usuario)) {
            throw new AccesoDenegadoException("Esta función es exclusiva del rol Apadrinado.");
        }
        return apadrinadoRepository.findByUsuarioId(usuario.getId())
                .orElseThrow(() -> new AccesoDenegadoException(
                        "Aún no pertenece a una comunidad. Solicite su incorporación con el código de acceso."));
    }

    // ==================== PERTENENCIA ====================

    /**
     * IDs de todas las comunidades bajo la responsabilidad del coordinador
     * actual: su comunidad principal más las asociadas.
     */
    @Transactional(readOnly = true)
    public Set<Long> comunidadesDelCoordinador() {
        Coordinador coordinador = coordinadorActual();
        if (coordinador == null) {
            return Collections.emptySet();
        }
        return comunidadesDe(coordinador);
    }

    public static Set<Long> comunidadesDe(Coordinador coordinador) {
        Set<Long> ids = new LinkedHashSet<>();
        if (coordinador.getComunidad() != null) {
            ids.add(coordinador.getComunidad().getId());
        }
        if (coordinador.getComunidades() != null) {
            for (Comunidad comunidad : coordinador.getComunidades()) {
                if (comunidad != null && comunidad.getId() != null) {
                    ids.add(comunidad.getId());
                }
            }
        }
        return ids;
    }

    /**
     * El apadrinado es accesible: el propio apadrinado, o (coordinador) uno
     * de cualquiera de sus comunidades o bajo su responsabilidad directa.
     */
    @Transactional(readOnly = true)
    public void verificarApadrinadoAccesible(Long apadrinadoId) {
        Apadrinado apadrinado = cargarApadrinado(apadrinadoId);
        Usuario usuario = usuarioActual();
        if (esApadrinado(usuario)) {
            Apadrinado propio = apadrinadoRepository.findByUsuarioId(usuario.getId())
                    .orElseThrow(() -> new AccesoDenegadoException("No tiene un perfil de apadrinado."));
            if (!propio.getId().equals(apadrinado.getId())) {
                throw new AccesoDenegadoException("No puede acceder a los datos de otro apadrinado.");
            }
        } else if (esCoordinador(usuario)) {
            verificarApadrinadoDelCoordinador(apadrinado);
        } else {
            throw new AccesoDenegadoException("Acceso denegado.");
        }
    }

    /**
     * Solo coordinador: el apadrinado pertenece a una de sus comunidades.
     * Se usa para expedientes, PDF, ZIP e historial.
     */
    @Transactional(readOnly = true)
    public Apadrinado verificarApadrinadoDeMiComunidad(Long apadrinadoId) {
        requerirCoordinador();
        Apadrinado apadrinado = cargarApadrinado(apadrinadoId);
        verificarApadrinadoDelCoordinador(apadrinado);
        return apadrinado;
    }

    private void verificarApadrinadoDelCoordinador(Apadrinado apadrinado) {
        Coordinador coordinador = coordinadorActual();
        if (coordinador == null) {
            throw new AccesoDenegadoException("No tiene un perfil de coordinador.");
        }
        boolean responsabilidadDirecta = apadrinado.getCoordinador() != null
                && apadrinado.getCoordinador().getId().equals(coordinador.getId());
        boolean perteneceASuComunidad = apadrinado.getComunidad() != null
                && comunidadesDe(coordinador).contains(apadrinado.getComunidad().getId());
        if (!responsabilidadDirecta && !perteneceASuComunidad) {
            throw new AccesoDenegadoException("El apadrinado no pertenece a su comunidad.");
        }
    }

    private Apadrinado cargarApadrinado(Long apadrinadoId) {
        if (apadrinadoId == null) {
            throw new AccesoDenegadoException("Se requiere un apadrinado válido.");
        }
        return apadrinadoRepository.findById(apadrinadoId)
                .orElseThrow(() -> new RuntimeException("Apadrinado no encontrado con ID: " + apadrinadoId));
    }

    @Transactional(readOnly = true)
    public void verificarCoordinadorPropio(Long coordinadorId) {
        if (coordinadorId == null) {
            throw new AccesoDenegadoException("Se requiere un coordinador válido.");
        }
        Coordinador coordinador = coordinadorActual();
        if (coordinador == null) {
            throw new AccesoDenegadoException(
                    "Esta función es exclusiva del rol Coordinador.");
        }
        if (!coordinador.getId().equals(coordinadorId)) {
            throw new AccesoDenegadoException(
                    "No puede acceder a los datos de otro coordinador.");
        }
    }

    /** La comunidad está bajo la responsabilidad del coordinador actual. */
    @Transactional(readOnly = true)
    public void verificarComunidadPropia(Long comunidadId) {
        if (comunidadId == null) {
            throw new AccesoDenegadoException("Se requiere una comunidad válida.");
        }
        Coordinador coordinador = coordinadorActual();
        if (coordinador == null) {
            throw new AccesoDenegadoException(
                    "Esta función es exclusiva del rol Coordinador.");
        }
        if (!comunidadesDe(coordinador).contains(comunidadId)) {
            throw new AccesoDenegadoException(
                    "La comunidad no está bajo su responsabilidad.");
        }
    }

    /**
     * La comunidad es accesible: bajo su responsabilidad (coordinador)
     * o la comunidad a la que pertenece (apadrinado).
     */
    @Transactional(readOnly = true)
    public void verificarComunidadAccesible(Long comunidadId) {
        if (comunidadId == null) {
            throw new AccesoDenegadoException("Se requiere una comunidad válida.");
        }
        Usuario usuario = usuarioActual();
        if (esCoordinador(usuario)) {
            if (comunidadesDelCoordinador().contains(comunidadId)) {
                return;
            }
            throw new AccesoDenegadoException("La comunidad no está bajo su responsabilidad.");
        }
        if (esApadrinado(usuario)) {
            Apadrinado apadrinado = apadrinadoRepository.findByUsuarioId(usuario.getId()).orElse(null);
            if (apadrinado != null && apadrinado.getComunidad() != null
                    && apadrinado.getComunidad().getId().equals(comunidadId)) {
                return;
            }
            throw new AccesoDenegadoException("Usted no pertenece a esa comunidad.");
        }
        throw new AccesoDenegadoException("Acceso denegado.");
    }

    // ==================== ACTIVIDADES Y ASIGNACIONES ====================

    /** Solo coordinador: la actividad pertenece a una de sus comunidades. */
    @Transactional(readOnly = true)
    public Actividad verificarActividadPropia(Long actividadId) {
        Actividad actividad = cargarActividad(actividadId);
        Coordinador coordinador = requerirCoordinadorActual();
        boolean deSuComunidad = actividad.getComunidad() != null
                && comunidadesDe(coordinador).contains(actividad.getComunidad().getId());
        if (!deSuComunidad) {
            throw new AccesoDenegadoException("La actividad no pertenece a sus comunidades.");
        }
        return actividad;
    }

    /**
     * La actividad es accesible: de una comunidad del coordinador, o
     * asignada al apadrinado (y no eliminada).
     */
    @Transactional(readOnly = true)
    public void verificarActividadAccesible(Long actividadId) {
        Actividad actividad = cargarActividad(actividadId);
        Usuario usuario = usuarioActual();
        if (esCoordinador(usuario)) {
            verificarActividadPropia(actividadId);
            return;
        }
        if (esApadrinado(usuario)) {
            Apadrinado propio = apadrinadoRepository.findByUsuarioId(usuario.getId())
                    .orElseThrow(() -> new AccesoDenegadoException("No tiene un perfil de apadrinado."));
            if (Boolean.TRUE.equals(actividad.getEliminada())
                    || !asignacionRepository.existsByActividadIdAndApadrinadoId(actividad.getId(), propio.getId())) {
                throw new AccesoDenegadoException("No puede acceder a esta actividad.");
            }
            return;
        }
        throw new AccesoDenegadoException("Acceso denegado.");
    }

    private Actividad cargarActividad(Long actividadId) {
        if (actividadId == null) {
            throw new AccesoDenegadoException("Se requiere una actividad válida.");
        }
        return actividadRepository.findById(actividadId)
                .orElseThrow(() -> new RuntimeException("Actividad no encontrada con ID: " + actividadId));
    }

    /**
     * La asignación es accesible: la propia (apadrinado) o la de un
     * apadrinado de sus comunidades (coordinador).
     */
    @Transactional(readOnly = true)
    public Asignacion verificarAsignacionAccesible(Long asignacionId) {
        Asignacion asignacion = cargarAsignacion(asignacionId);
        Usuario usuario = usuarioActual();
        if (esApadrinado(usuario)) {
            verificarAsignacionPropia(asignacion);
        } else if (esCoordinador(usuario)) {
            verificarActividadPropia(asignacion.getActividad().getId());
        } else {
            throw new AccesoDenegadoException("Acceso denegado.");
        }
        return asignacion;
    }

    /** Solo apadrinado: la asignación es suya y la actividad sigue visible. */
    @Transactional(readOnly = true)
    public Asignacion verificarAsignacionDelApadrinado(Long asignacionId) {
        Asignacion asignacion = cargarAsignacion(asignacionId);
        verificarAsignacionPropia(asignacion);
        return asignacion;
    }

    /** Solo coordinador: la asignación es de una de sus comunidades. */
    @Transactional(readOnly = true)
    public Asignacion verificarAsignacionDelCoordinador(Long asignacionId) {
        Asignacion asignacion = cargarAsignacion(asignacionId);
        verificarActividadPropia(asignacion.getActividad().getId());
        return asignacion;
    }

    private void verificarAsignacionPropia(Asignacion asignacion) {
        Apadrinado propio = requerirApadrinadoActual();
        if (!asignacion.getApadrinado().getId().equals(propio.getId())
                || Boolean.TRUE.equals(asignacion.getActividad().getEliminada())) {
            throw new AccesoDenegadoException("No puede acceder a esta actividad.");
        }
    }

    private Asignacion cargarAsignacion(Long asignacionId) {
        if (asignacionId == null) {
            throw new AccesoDenegadoException("Se requiere una asignación válida.");
        }
        return asignacionRepository.findById(asignacionId)
                .orElseThrow(() -> new RuntimeException("Asignación no encontrada con ID: " + asignacionId));
    }

    // ==================== EXPEDIENTES, DOCUMENTOS Y CARTAS ====================

    /** Solo coordinador: el expediente es de un apadrinado de sus comunidades. */
    @Transactional(readOnly = true)
    public Expediente verificarExpedienteAccesible(Long expedienteId) {
        if (expedienteId == null) {
            throw new AccesoDenegadoException("Se requiere un expediente válido.");
        }
        Expediente expediente = expedienteRepository.findById(expedienteId)
                .orElseThrow(() -> new RuntimeException("Expediente no encontrado con ID: " + expedienteId));
        if (expediente.getApadrinado() == null) {
            throw new AccesoDenegadoException("Expediente sin apadrinado asociado.");
        }
        verificarApadrinadoDeMiComunidad(expediente.getApadrinado().getId());
        return expediente;
    }

    /**
     * Documento accesible:
     * - material del coordinador: quien pueda ver la actividad;
     * - archivo de una entrega: el apadrinado dueño o su coordinador.
     */
    @Transactional(readOnly = true)
    public Documento verificarDocumentoAccesible(Long documentoId) {
        if (documentoId == null) {
            throw new AccesoDenegadoException("Se requiere un documento válido.");
        }
        Documento documento = documentoRepository.findById(documentoId)
                .orElseThrow(() -> new RuntimeException("Documento no encontrado con ID: " + documentoId));
        if (documento.getOrigen() == OrigenDocumento.COORDINADOR) {
            if (documento.getActividad() == null) {
                throw new AccesoDenegadoException("El documento no tiene actividad asociada.");
            }
            verificarActividadAccesible(documento.getActividad().getId());
        } else {
            if (documento.getExpediente() == null || documento.getExpediente().getApadrinado() == null) {
                throw new AccesoDenegadoException("El documento no tiene apadrinado asociado.");
            }
            verificarApadrinadoAccesible(documento.getExpediente().getApadrinado().getId());
        }
        return documento;
    }

    @Transactional(readOnly = true)
    public Carta verificarCartaAccesible(Long cartaId) {
        if (cartaId == null) {
            throw new AccesoDenegadoException("Se requiere una carta válida.");
        }
        Carta carta = cartaRepository.findById(cartaId)
                .orElseThrow(() -> new RuntimeException("Carta no encontrada con ID: " + cartaId));
        if (carta.getApadrinado() == null) {
            throw new AccesoDenegadoException("La carta no tiene apadrinado asociado.");
        }
        verificarApadrinadoAccesible(carta.getApadrinado().getId());
        return carta;
    }

    /**
     * El usuario es accesible: el propio, o un apadrinado de sus comunidades.
     */
    @Transactional(readOnly = true)
    public void verificarUsuarioAccesible(Long usuarioId) {
        if (usuarioId == null) {
            throw new AccesoDenegadoException("Se requiere un usuario válido.");
        }
        Usuario usuario = usuarioActual();
        if (usuario.getId().equals(usuarioId)) {
            return;
        }
        Apadrinado apadrinado = apadrinadoRepository.findByUsuarioId(usuarioId).orElse(null);
        if (apadrinado == null) {
            throw new AccesoDenegadoException(
                    "No puede actuar sobre los recursos de otro usuario.");
        }
        verificarApadrinadoAccesible(apadrinado.getId());
    }

    public Optional<Coordinador> coordinadorActualOptional() {
        return Optional.ofNullable(coordinadorActual());
    }
}
