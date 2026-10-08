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
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Comunidad;
import com.example.backend.entity.Coordinador;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.ActividadRepository;
import com.example.backend.repository.CartaRepository;
import com.example.backend.repository.CoordinadorRepository;
import com.example.backend.repository.DocumentoRepository;
import com.example.backend.repository.ExpedienteRepository;
import com.example.backend.repository.MaterialApoyoRepository;
import com.example.backend.repository.UsuarioRepository;

import lombok.RequiredArgsConstructor;

/**
 * Servicio central de autorización (Fase B - RBAC y control de pertenencia).
 *
 * Reglas implementadas:
 * - Apadrinado: solo accede a sus propios recursos (su expediente, actividades,
 *   documentos, cartas, notificaciones y perfil).
 * - Coordinador: solo accede a los recursos de los apadrinados bajo su
 *   responsabilidad y ejecuta las funciones propias de coordinador.
 * - FASE F: el coordinador accede a los recursos de TODAS las comunidades
 *   bajo su responsabilidad (comunidad principal + comunidades asociadas).
 * - Cualquier otro perfil no tiene acceso a funciones operativas.
 */
@Service
@RequiredArgsConstructor
public class SeguridadService {

    private final UsuarioRepository usuarioRepository;
    private final ApadrinadoRepository apadrinadoRepository;
    private final CoordinadorRepository coordinadorRepository;
    private final ActividadRepository actividadRepository;
    private final CartaRepository cartaRepository;
    private final DocumentoRepository documentoRepository;
    private final ExpedienteRepository expedienteRepository;
    private final MaterialApoyoRepository materialApoyoRepository;

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

    // ==================== PERTENENCIA ====================

    /**
     * FASE F: devuelve los IDs de todas las comunidades bajo la
     * responsabilidad del coordinador actual: su comunidad principal
     * más las comunidades asociadas (tabla coordinador_comunidad).
     * Un coordinador puede administrar una o varias comunidades.
     */
    @Transactional(readOnly = true)
    public Set<Long> comunidadesDelCoordinador() {
        Coordinador coordinador = coordinadorActual();
        if (coordinador == null) {
            return Collections.emptySet();
        }
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
     * Verifica que el apadrinado indicado sea accesible para el usuario actual:
     * el propio apadrinado, o uno bajo la responsabilidad directa del
     * coordinador, o uno perteneciente a cualquiera de sus comunidades.
     */
    @Transactional(readOnly = true)
    public void verificarApadrinadoAccesible(Long apadrinadoId) {
        if (apadrinadoId == null) {
            throw new AccesoDenegadoException("Se requiere un apadrinado válido.");
        }
        Apadrinado apadrinado = apadrinadoRepository.findById(apadrinadoId)
                .orElseThrow(() -> new RuntimeException("Apadrinado no encontrado con ID: " + apadrinadoId));

        Usuario usuario = usuarioActual();
        if (esApadrinado(usuario)) {
            Apadrinado propio = apadrinadoRepository.findByUsuarioId(usuario.getId())
                    .orElseThrow(() -> new AccesoDenegadoException("No tiene un perfil de apadrinado."));
            if (!propio.getId().equals(apadrinado.getId())) {
                throw new AccesoDenegadoException(
                        "No puede acceder al expediente de otro apadrinado.");
            }
        } else if (esCoordinador(usuario)) {
            Coordinador coordinador = coordinadorRepository.findByUsuarioId(usuario.getId())
                    .orElseThrow(() -> new AccesoDenegadoException("No tiene un perfil de coordinador."));
            boolean responsabilidadDirecta = apadrinado.getCoordinador() != null
                    && apadrinado.getCoordinador().getId().equals(coordinador.getId());
            // FASE F: también son accesibles los apadrinados de sus comunidades
            boolean perteneceASuComunidad = apadrinado.getComunidad() != null
                    && comunidadesDelCoordinador().contains(apadrinado.getComunidad().getId());
            if (!responsabilidadDirecta && !perteneceASuComunidad) {
                throw new AccesoDenegadoException(
                        "El apadrinado no pertenece a su comunidad.");
            }
        } else {
            throw new AccesoDenegadoException("Acceso denegado.");
        }
    }

    /**
     * Verifica que el coordinador indicado sea el propio.
     */
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

    /**
     * Verifica que la comunidad indicada esté bajo la responsabilidad
     * del coordinador actual (principal o asociada).
     */
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
        // FASE F: cualquiera de las comunidades bajo su responsabilidad
        if (!comunidadesDelCoordinador().contains(comunidadId)) {
            throw new AccesoDenegadoException(
                    "La comunidad no está bajo su responsabilidad.");
        }
    }

    /**
     * Verifica que la actividad indicada sea accesible:
     * propia (apadrinado) o de un apadrinado bajo su responsabilidad (coordinador).
     */
    @Transactional(readOnly = true)
    public void verificarActividadAccesible(Long actividadId) {
        if (actividadId == null) {
            throw new AccesoDenegadoException("Se requiere una actividad válida.");
        }
        var actividad = actividadRepository.findById(actividadId)
                .orElseThrow(() -> new RuntimeException("Actividad no encontrada con ID: " + actividadId));

        Usuario usuario = usuarioActual();
        if (esApadrinado(usuario)) {
            Apadrinado propio = apadrinadoRepository.findByUsuarioId(usuario.getId())
                    .orElseThrow(() -> new AccesoDenegadoException("No tiene un perfil de apadrinado."));
            if (actividad.getApadrinado() == null
                    || !actividad.getApadrinado().getId().equals(propio.getId())) {
                throw new AccesoDenegadoException("No puede acceder a esta actividad.");
            }
        } else if (esCoordinador(usuario)) {
            Coordinador coordinador = coordinadorRepository.findByUsuarioId(usuario.getId())
                    .orElseThrow(() -> new AccesoDenegadoException("No tiene un perfil de coordinador."));
            boolean esDelCoordinador = actividad.getCoordinador() != null
                    && actividad.getCoordinador().getId().equals(coordinador.getId());
            // FASE F: también son accesibles las actividades de los
            // apadrinados de cualquiera de sus comunidades
            boolean esDeSuComunidad = actividad.getApadrinado() != null
                    && actividad.getApadrinado().getComunidad() != null
                    && comunidadesDelCoordinador()
                            .contains(actividad.getApadrinado().getComunidad().getId());
            if (!esDelCoordinador && !esDeSuComunidad) {
                throw new AccesoDenegadoException("La actividad no pertenece a su comunidad.");
            }
        } else {
            throw new AccesoDenegadoException("Acceso denegado.");
        }
    }

    /**
     * Verifica que el expediente indicado sea accesible según el apadrinado dueño.
     */
    @Transactional(readOnly = true)
    public void verificarExpedienteAccesible(Long expedienteId) {
        if (expedienteId == null) {
            throw new AccesoDenegadoException("Se requiere un expediente válido.");
        }
        var expediente = expedienteRepository.findById(expedienteId)
                .orElseThrow(() -> new RuntimeException("Expediente no encontrado con ID: " + expedienteId));
        if (expediente.getApadrinado() == null) {
            throw new AccesoDenegadoException("Expediente sin apadrinado asociado.");
        }
        verificarApadrinadoAccesible(expediente.getApadrinado().getId());
    }

    /**
     * Verifica que la carta indicada sea accesible según su apadrinado.
     */
    @Transactional(readOnly = true)
    public void verificarCarteraAccesible(Long cartaId) {
        if (cartaId == null) {
            throw new AccesoDenegadoException("Se requiere una carta válida.");
        }
        var carta = cartaRepository.findById(cartaId)
                .orElseThrow(() -> new RuntimeException("Carta no encontrada con id: " + cartaId));
        if (carta.getApadrinado() == null) {
            throw new AccesoDenegadoException("La carta no tiene apadrinado asociado.");
        }
        verificarApadrinadoAccesible(carta.getApadrinado().getId());
    }

    /**
     * Verifica que el documento indicado sea accesible según su expediente.
     */
    @Transactional(readOnly = true)
    public void verificarDocumentoAccesible(Long documentoId) {
        if (documentoId == null) {
            throw new AccesoDenegadoException("Se requiere un documento válido.");
        }
        var documento = documentoRepository.findById(documentoId)
                .orElseThrow(() -> new RuntimeException("Documento no encontrado con ID: " + documentoId));
        if (documento.getExpediente() == null) {
            throw new AccesoDenegadoException("El documento no tiene expediente asociado.");
        }
        verificarExpedienteAccesible(documento.getExpediente().getId());
    }

    /**
     * Verifica que la comunidad indicada sea accesible para el usuario actual:
     * la comunidad bajo su responsabilidad (coordinador) o la comunidad a la
     * que pertenece (apadrinado).
     */
    @Transactional(readOnly = true)
    public void verificarComunidadAccesible(Long comunidadId) {
        if (comunidadId == null) {
            throw new AccesoDenegadoException("Se requiere una comunidad válida.");
        }
        Usuario usuario = usuarioActual();
        if (esCoordinador(usuario)) {
            // FASE F: cualquiera de las comunidades bajo su responsabilidad
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

    /**
     * Verifica que el material de apoyo indicado sea accesible:
     * material de la propia comunidad (apadrinado) o bajo su
     * responsabilidad (coordinador).
     */
    @Transactional(readOnly = true)
    public void verificarMaterialAccesible(Long materialId) {
        if (materialId == null) {
            throw new AccesoDenegadoException("Se requiere un material de apoyo válido.");
        }
        var material = materialApoyoRepository.findById(materialId)
                .orElseThrow(() -> new RuntimeException(
                        "Material de apoyo no encontrado con ID: " + materialId));
        if (material.getComunidad() == null) {
            throw new AccesoDenegadoException("El material no tiene comunidad asociada.");
        }
        verificarComunidadAccesible(material.getComunidad().getId());
    }

    /**
     * Verifica que el usuario indicado sea accesible para el usuario actual:
     * su propio usuario, o un apadrinado bajo su responsabilidad (coordinador).
     */
    @Transactional(readOnly = true)
    public void verificarUsuarioAccesible(Long usuarioId) {
        if (usuarioId == null) {
            throw new AccesoDenegadoException("Se requiere un usuario válido.");
        }
        Usuario usuario = usuarioActual();
        if (usuario.getId().equals(usuarioId)) {
            return; // propio
        }
        Apadrinado apadrinado = apadrinadoRepository.findByUsuarioId(usuarioId).orElse(null);
        if (apadrinado == null) {
            throw new AccesoDenegadoException(
                    "No puede actuar sobre los recursos de otro usuario.");
        }
        verificarApadrinadoAccesible(apadrinado.getId());
    }

    /**
     * Devuelve el Optional del coordinador actual (para flujos opcionales).
     */
    public Optional<Coordinador> coordinadorActualOptional() {
        return Optional.ofNullable(coordinadorActual());
    }
}
