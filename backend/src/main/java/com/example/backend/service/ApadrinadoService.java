package com.example.backend.service;

import java.time.LocalDate;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.dto.ApadrinadoRequestDTO;
import com.example.backend.dto.ApadrinadoResponseDTO;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Comunidad;
import com.example.backend.entity.Coordinador;
import com.example.backend.entity.Expediente;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.ComunidadRepository;
import com.example.backend.repository.CoordinadorRepository;
import com.example.backend.entity.Rol;
import com.example.backend.repository.ExpedienteRepository;
import com.example.backend.repository.RolRepository;
import com.example.backend.repository.UsuarioRepository;
import org.springframework.security.crypto.password.PasswordEncoder;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class ApadrinadoService {

    private final ApadrinadoRepository apadrinadoRepository;
    private final UsuarioRepository usuarioRepository;
    private final CoordinadorRepository coordinadorRepository;
    private final ComunidadRepository comunidadRepository;
    private final ExpedienteRepository expedienteRepository;
    private final RolRepository rolRepository;
    private final PasswordEncoder passwordEncoder;
    private final ConvertidorDTO convertidor;
    private final ActividadService actividadService;
    private final DocumentoService documentoService;
    private final com.example.backend.repository.DocumentoRepository documentoRepository;
    private final com.example.backend.repository.CartaRepository cartaRepository;
    private final com.example.backend.repository.EntregaRepository entregaRepository;
    private final com.example.backend.repository.AsignacionRepository asignacionRepository;

    @Transactional(readOnly = true)
    public List<ApadrinadoResponseDTO> listarTodos() {
        return apadrinadoRepository.findAll().stream()
                .map(this::convertirAResponseDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public ApadrinadoResponseDTO obtenerPorId(Long id) {
        Apadrinado apadrinado = apadrinadoRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Apadrinado no encontrado con ID: " + id));
        return convertirAResponseDTO(apadrinado);
    }

    @Transactional(readOnly = true)
    public ApadrinadoResponseDTO obtenerPorUsuarioId(Long usuarioId) {
        Apadrinado apadrinado = apadrinadoRepository.findByUsuarioId(usuarioId)
                .orElseThrow(() -> new RuntimeException("Apadrinado no encontrado para el usuario ID: " + usuarioId));
        return convertirAResponseDTO(apadrinado);
    }

    @Transactional(readOnly = true)
    public List<ApadrinadoResponseDTO> listarPorCoordinador(Long coordinadorId) {
        return apadrinadoRepository.findByCoordinadorId(coordinadorId).stream()
                .map(this::convertirAResponseDTO)
                .collect(Collectors.toList());
    }

    /**
     * FASE F: apadrinados accesibles para el coordinador: los que están bajo
     * su responsabilidad directa más los pertenecientes a cualquiera de
     * sus comunidades (principal y asociadas).
     */
    @Transactional(readOnly = true)
    public List<ApadrinadoResponseDTO> listarAccesiblesPorCoordinador(Coordinador coordinador) {
        Set<Comunidad> comunidades = new LinkedHashSet<>();
        if (coordinador.getComunidad() != null) {
            comunidades.add(coordinador.getComunidad());
        }
        if (coordinador.getComunidades() != null) {
            comunidades.addAll(coordinador.getComunidades());
        }
        List<Long> comunidadIds = comunidades.stream()
                .map(Comunidad::getId)
                .filter(Objects::nonNull)
                .collect(Collectors.toList());

        List<Apadrinado> apadrinados;
        if (comunidadIds.isEmpty()) {
            apadrinados = apadrinadoRepository.findByCoordinadorId(coordinador.getId());
        } else {
            apadrinados = apadrinadoRepository.findAccesiblesPorCoordinador(
                    coordinador.getId(), comunidadIds);
        }
        return apadrinados.stream()
                .map(this::convertirAResponseDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<ApadrinadoResponseDTO> listarPorComunidad(Long comunidadId) {
        return apadrinadoRepository.findByComunidadId(comunidadId).stream()
                .map(this::convertirAResponseDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public ApadrinadoResponseDTO crear(ApadrinadoRequestDTO dto) {
        Usuario usuario;

        if (dto.getUsuarioId() != null) {
            if (apadrinadoRepository.existsByUsuarioId(dto.getUsuarioId())) {
                throw new RuntimeException("El usuario con ID " + dto.getUsuarioId() + " ya está registrado como apadrinado.");
            }
            usuario = usuarioRepository.findById(dto.getUsuarioId())
                    .orElseThrow(() -> new RuntimeException("Usuario no encontrado con ID: " + dto.getUsuarioId()));
        } else if (dto.getCorreo() != null && !dto.getCorreo().isBlank()) {
            String correoClean = dto.getCorreo().trim().toLowerCase();
            if (usuarioRepository.existsByCorreo(correoClean)) {
                throw new RuntimeException("Ya existe un usuario registrado con el correo: " + correoClean);
            }
            if (dto.getNombre() == null || dto.getNombre().isBlank()) {
                throw new RuntimeException("El nombre del apadrinado es obligatorio.");
            }
            Rol rolApadrinado = rolRepository.findByNombre("Apadrinado")
                    .orElseGet(() -> rolRepository.save(new Rol(null, "Apadrinado")));
            String rawPass = (dto.getPassword() != null && !dto.getPassword().isBlank())
                    ? dto.getPassword().trim()
                    : "password123";

            usuario = usuarioRepository.save(Usuario.builder()
                    .nombre(dto.getNombre().trim())
                    .correo(correoClean)
                    .password(passwordEncoder.encode(rawPass))
                    .rol(rolApadrinado)
                    .build());
        } else {
            throw new RuntimeException("Debe proporcionar un 'usuarioId' existente o ingresar 'nombre' y 'correo' para el nuevo apadrinado.");
        }

        Coordinador coordinador = null;
        if (dto.getCoordinadorId() != null) {
            coordinador = coordinadorRepository.findById(dto.getCoordinadorId())
                    .orElseThrow(() -> new RuntimeException("Coordinador no encontrado con ID: " + dto.getCoordinadorId()));
        }

        Comunidad comunidad = null;
        if (dto.getComunidadId() != null) {
            comunidad = comunidadRepository.findById(dto.getComunidadId())
                    .orElseThrow(() -> new RuntimeException("Comunidad no encontrada con ID: " + dto.getComunidadId()));
        } else if (coordinador != null && coordinador.getComunidad() != null) {
            // Heredar comunidad del coordinador por defecto
            comunidad = coordinador.getComunidad();
        }

        Apadrinado apadrinado = Apadrinado.builder()
                .usuario(usuario)
                .coordinador(coordinador)
                .comunidad(comunidad)
                .build();

        Apadrinado guardado = apadrinadoRepository.save(apadrinado);

        // Regla de Negocio: Creación automática del expediente digital único para el apadrinado
        if (!expedienteRepository.existsByApadrinadoId(guardado.getId())) {
            Expediente expediente = Expediente.builder()
                    .apadrinado(guardado)
                    .fechaCreacion(LocalDate.now())
                    .build();
            expedienteRepository.save(expediente);
        }

        // Recibe las actividades asignadas a toda su comunidad
        actividadService.asignarActividadesDeComunidad(guardado,
                coordinador != null ? coordinador.getUsuario() : null);
        return convertirAResponseDTO(guardado);
    }

    @Transactional
    public ApadrinadoResponseDTO actualizar(Long id, ApadrinadoRequestDTO dto) {
        Apadrinado apadrinado = apadrinadoRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Apadrinado no encontrado con ID: " + id));

        if (dto.getCoordinadorId() != null) {
            Coordinador coordinador = coordinadorRepository.findById(dto.getCoordinadorId())
                    .orElseThrow(() -> new RuntimeException("Coordinador no encontrado con ID: " + dto.getCoordinadorId()));
            apadrinado.setCoordinador(coordinador);
        }

        if (dto.getComunidadId() != null) {
            Comunidad comunidad = comunidadRepository.findById(dto.getComunidadId())
                    .orElseThrow(() -> new RuntimeException("Comunidad no encontrada con ID: " + dto.getComunidadId()));
            apadrinado.setComunidad(comunidad);
        }

        Apadrinado actualizado = apadrinadoRepository.save(apadrinado);
        actividadService.asignarActividadesDeComunidad(actualizado,
                actualizado.getCoordinador() != null ? actualizado.getCoordinador().getUsuario() : null);
        return convertirAResponseDTO(actualizado);
    }

    @Transactional
    public void eliminar(Long id) {
        if (!apadrinadoRepository.existsById(id)) {
            throw new RuntimeException("Apadrinado no encontrado con ID: " + id);
        }
        // Las entregas enviadas forman parte de la trazabilidad del expediente
        boolean conEntregas = asignacionRepository.findByApadrinadoIdOrderByFechaAsignacionAsc(id).stream()
                .anyMatch(s -> entregaRepository.existsByAsignacionIdAndEstadoNot(
                        s.getId(), com.example.backend.entity.EstadoEntrega.BORRADOR));
        if (conEntregas) {
            throw new RuntimeException(
                    "El apadrinado ya tiene entregas registradas en su expediente y no se puede eliminar.");
        }
        expedienteRepository.findByApadrinadoId(id).ifPresent(expediente -> {
            documentoService.eliminarTodos(documentoRepository.findByExpedienteId(expediente.getId()));
            cartaRepository.deleteAll(cartaRepository.findByExpedienteId(expediente.getId()));
            cartaRepository.flush();
            expedienteRepository.delete(expediente);
            expedienteRepository.flush();
        });
        apadrinadoRepository.deleteById(id);
    }

    public ApadrinadoResponseDTO convertirAResponseDTO(Apadrinado apadrinado) {
        return convertidor.apadrinado(apadrinado);
    }
}
