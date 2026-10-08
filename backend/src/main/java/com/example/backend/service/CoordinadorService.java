package com.example.backend.service;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.config.AccesoDenegadoException;
import com.example.backend.dto.CoordinadorRequestDTO;
import com.example.backend.dto.CoordinadorResponseDTO;
import com.example.backend.dto.ComunidadResponseDTO;
import com.example.backend.entity.Comunidad;
import com.example.backend.entity.Coordinador;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ComunidadRepository;
import com.example.backend.repository.CoordinadorRepository;
import com.example.backend.repository.UsuarioRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class CoordinadorService {

    private final CoordinadorRepository coordinadorRepository;
    private final UsuarioRepository usuarioRepository;
    private final ComunidadRepository comunidadRepository;

    @Transactional(readOnly = true)
    public List<CoordinadorResponseDTO> listarTodos() {
        return coordinadorRepository.findAll().stream()
                .map(this::convertirAResponseDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public CoordinadorResponseDTO obtenerPorId(Long id) {
        Coordinador coordinador = coordinadorRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Coordinador no encontrado con ID: " + id));
        return convertirAResponseDTO(coordinador);
    }

    @Transactional(readOnly = true)
    public CoordinadorResponseDTO obtenerPorUsuarioId(Long usuarioId) {
        Coordinador coordinador = coordinadorRepository.findByUsuarioId(usuarioId)
                .orElseThrow(() -> new RuntimeException("Coordinador no encontrado para el usuario ID: " + usuarioId));
        return convertirAResponseDTO(coordinador);
    }

    @Transactional(readOnly = true)
    public List<CoordinadorResponseDTO> listarPorComunidad(Long comunidadId) {
        return coordinadorRepository.findByComunidadId(comunidadId).stream()
                .map(this::convertirAResponseDTO)
                .collect(Collectors.toList());
    }

    // ==================== FASE F: MÚLTIPLES COMUNIDADES ====================

    /**
     * Lista todas las comunidades bajo la responsabilidad del coordinador
     * (su comunidad principal más las comunidades asociadas).
     */
    @Transactional(readOnly = true)
    public List<ComunidadResponseDTO> listarComunidadesDelCoordinador(Long coordinadorId) {
        Coordinador coordinador = coordinadorRepository.findById(coordinadorId)
                .orElseThrow(() -> new RuntimeException("Coordinador no encontrado con ID: " + coordinadorId));
        return convertirComunidades(coordinador);
    }

    /**
     * Asocia una comunidad existente al coordinador, ampliando las
     * comunidades bajo su responsabilidad.
     *
     * Regla de negocio (FASE F): una comunidad solo puede estar bajo la
     * responsabilidad de un único coordinador. La operación es idempotente:
     * si la comunidad ya es suya (principal o asociada), no se duplica.
     */
    @Transactional
    public List<ComunidadResponseDTO> asociarComunidad(Long coordinadorId, Long comunidadId) {
        Coordinador coordinador = coordinadorRepository.findById(coordinadorId)
                .orElseThrow(() -> new RuntimeException("Coordinador no encontrado con ID: " + coordinadorId));
        Comunidad comunidad = comunidadRepository.findById(comunidadId)
                .orElseThrow(() -> new RuntimeException("Comunidad no encontrada con ID: " + comunidadId));

        // Idempotencia: ya es su comunidad principal o ya está asociada
        if (coordinador.getComunidad() != null
                && coordinador.getComunidad().getId().equals(comunidadId)) {
            return convertirComunidades(coordinador);
        }
        if (coordinador.getComunidades() != null
                && coordinador.getComunidades().stream()
                        .anyMatch(c -> c.getId().equals(comunidadId))) {
            return convertirComunidades(coordinador);
        }

        // Exclusividad: la comunidad no puede estar bajo otra responsabilidad
        if (comunidadTieneOtroResponsable(comunidadId, coordinadorId)) {
            throw new AccesoDenegadoException(
                    "La comunidad ya está bajo la responsabilidad de otro coordinador.");
        }

        if (coordinador.getComunidades() == null) {
            coordinador.setComunidades(new ArrayList<>());
        }
        coordinador.getComunidades().add(comunidad);
        coordinadorRepository.save(coordinador);
        return convertirComunidades(coordinador);
    }

    /**
     * Desasocia una comunidad de las responsabilidades del coordinador.
     * La comunidad principal no puede desasociarse por esta vía.
     */
    @Transactional
    public List<ComunidadResponseDTO> desasociarComunidad(Long coordinadorId, Long comunidadId) {
        Coordinador coordinador = coordinadorRepository.findById(coordinadorId)
                .orElseThrow(() -> new RuntimeException("Coordinador no encontrado con ID: " + coordinadorId));
        if (coordinador.getComunidad() != null
                && coordinador.getComunidad().getId().equals(comunidadId)) {
            throw new AccesoDenegadoException(
                    "La comunidad principal no puede desasociarse por esta vía.");
        }
        boolean eliminada = coordinador.getComunidades() != null
                && coordinador.getComunidades().removeIf(c -> comunidadId.equals(c.getId()));
        if (eliminada) {
            coordinadorRepository.save(coordinador);
        }
        return convertirComunidades(coordinador);
    }

    /**
     * Indica si la comunidad ya está bajo la responsabilidad de otro
     * coordinador (como comunidad principal o como asociada).
     */
    private boolean comunidadTieneOtroResponsable(Long comunidadId, Long coordinadorId) {
        boolean principalDeOtro = coordinadorRepository.findByComunidadId(comunidadId).stream()
                .anyMatch(c -> !c.getId().equals(coordinadorId));
        boolean asociadaDeOtro = coordinadorRepository.findByComunidadAsociadaId(comunidadId).stream()
                .anyMatch(c -> !c.getId().equals(coordinadorId));
        return principalDeOtro || asociadaDeOtro;
    }

    /**
     * Convierte el conjunto de comunidades del coordinador (principal
     * + asociadas) a DTOs, sin duplicados y con la principal primero.
     */
    private List<ComunidadResponseDTO> convertirComunidades(Coordinador coordinador) {
        Set<Comunidad> todas = new LinkedHashSet<>();
        if (coordinador.getComunidad() != null) {
            todas.add(coordinador.getComunidad());
        }
        if (coordinador.getComunidades() != null) {
            todas.addAll(coordinador.getComunidades());
        }
        return todas.stream()
                .map(c -> ComunidadResponseDTO.builder()
                        .id(c.getId())
                        .nombre(c.getNombre())
                        .municipio(c.getMunicipio())
                        .departamento(c.getDepartamento())
                        .build())
                .collect(Collectors.toList());
    }

    @Transactional
    public CoordinadorResponseDTO crear(CoordinadorRequestDTO dto) {
        if (dto.getUsuarioId() == null) {
            throw new RuntimeException("El ID de usuario es obligatorio.");
        }

        if (coordinadorRepository.existsByUsuarioId(dto.getUsuarioId())) {
            throw new RuntimeException("El usuario con ID " + dto.getUsuarioId() + " ya está registrado como coordinador.");
        }

        Usuario usuario = usuarioRepository.findById(dto.getUsuarioId())
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado con ID: " + dto.getUsuarioId()));

        Comunidad comunidad = null;
        if (dto.getComunidadId() != null) {
            comunidad = comunidadRepository.findById(dto.getComunidadId())
                    .orElseThrow(() -> new RuntimeException("Comunidad no encontrada con ID: " + dto.getComunidadId()));
        }

        Coordinador coordinador = Coordinador.builder()
                .usuario(usuario)
                .comunidad(comunidad)
                .build();

        Coordinador guardado = coordinadorRepository.save(coordinador);
        return convertirAResponseDTO(guardado);
    }

    @Transactional
    public CoordinadorResponseDTO actualizar(Long id, CoordinadorRequestDTO dto) {
        Coordinador coordinador = coordinadorRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Coordinador no encontrado con ID: " + id));

        if (dto.getComunidadId() != null) {
            Comunidad comunidad = comunidadRepository.findById(dto.getComunidadId())
                    .orElseThrow(() -> new RuntimeException("Comunidad no encontrada con ID: " + dto.getComunidadId()));
            coordinador.setComunidad(comunidad);
        }

        Coordinador actualizado = coordinadorRepository.save(coordinador);
        return convertirAResponseDTO(actualizado);
    }

    @Transactional
    public void eliminar(Long id) {
        if (!coordinadorRepository.existsById(id)) {
            throw new RuntimeException("Coordinador no encontrado con ID: " + id);
        }
        coordinadorRepository.deleteById(id);
    }

    public CoordinadorResponseDTO convertirAResponseDTO(Coordinador coordinador) {
        Long usuarioId = null;
        String nombre = null;
        String correo = null;

        if (coordinador.getUsuario() != null) {
            usuarioId = coordinador.getUsuario().getId();
            nombre = coordinador.getUsuario().getNombre();
            correo = coordinador.getUsuario().getCorreo();
        }

        Long comunidadId = null;
        String comunidadNombre = null;
        if (coordinador.getComunidad() != null) {
            comunidadId = coordinador.getComunidad().getId();
            comunidadNombre = coordinador.getComunidad().getNombre();
        }

        return CoordinadorResponseDTO.builder()
                .id(coordinador.getId())
                .usuarioId(usuarioId)
                .nombre(nombre)
                .correo(correo)
                .comunidadId(comunidadId)
                .comunidadNombre(comunidadNombre)
                .comunidades(convertirComunidades(coordinador))
                .build();
    }
}
