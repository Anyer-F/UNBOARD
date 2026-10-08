package com.example.backend.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.dto.CartaRequestDTO;
import com.example.backend.dto.CartaResponseDTO;
import com.example.backend.dto.PagedResponseDTO;
import com.example.backend.entity.Actividad;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Carta;
import com.example.backend.entity.Carta.EstadoCarta;
import com.example.backend.entity.Expediente;
import com.example.backend.entity.Usuario;
import com.example.backend.helper.PaginationHelper;
import com.example.backend.repository.ActividadRepository;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.CartaRepository;
import com.example.backend.repository.ExpedienteRepository;
import com.example.backend.repository.UsuarioRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class CartaService {

    private final CartaRepository cartaRepository;
    private final ApadrinadoRepository apadrinadoRepository;
    private final ExpedienteRepository expedienteRepository;
    private final ActividadRepository actividadRepository;
    private final UsuarioRepository usuarioRepository;

    @Transactional(readOnly = true)
    public List<CartaResponseDTO> listarTodas() {
        return cartaRepository.findAll().stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public CartaResponseDTO obtenerPorId(Long id) {
        Carta carta = cartaRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Carta no encontrada con id: " + id));
        return mapToDTO(carta);
    }

    @Transactional(readOnly = true)
    public List<CartaResponseDTO> listarPorApadrinado(Long apadrinadoId) {
        return cartaRepository.findByApadrinadoId(apadrinadoId).stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<CartaResponseDTO> listarPorExpediente(Long expedienteId) {
        return cartaRepository.findByExpedienteId(expedienteId).stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<CartaResponseDTO> listarPorActividad(Long actividadId) {
        return cartaRepository.findByActividadId(actividadId).stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<CartaResponseDTO> listarPorEstado(EstadoCarta estado) {
        return cartaRepository.findByEstado(estado).stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<CartaResponseDTO> listarPorApadrinadoYEstado(Long apadrinadoId, EstadoCarta estado) {
        return cartaRepository.findByApadrinadoIdAndEstado(apadrinadoId, estado).stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<CartaResponseDTO> listarPorCoordinador(Long coordinadorId) {
        return cartaRepository.findByApadrinadoCoordinadorId(coordinadorId).stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<CartaResponseDTO> listarPorCoordinadorYEstado(Long coordinadorId, EstadoCarta estado) {
        return cartaRepository.findByApadrinadoCoordinadorIdAndEstado(coordinadorId, estado).stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public PagedResponseDTO<CartaResponseDTO> listarPorCoordinadorPaginado(
            Long coordinadorId, EstadoCarta estado, String titulo, int pagina, int tamano, String sortBy, String sortDir) {
        Sort sort = sortDir.equalsIgnoreCase("desc") ? Sort.by(sortBy).descending() : Sort.by(sortBy).ascending();
        Pageable pageable = PageRequest.of(pagina, tamano, sort);
        Page<Carta> page;

        if (estado != null && titulo != null && !titulo.isEmpty()) {
            page = cartaRepository.findByApadrinadoCoordinadorIdAndEstadoAndTituloContainingIgnoreCase(
                    coordinadorId, estado, titulo, pageable);
        } else if (estado != null) {
            page = cartaRepository.findByApadrinadoCoordinadorIdAndEstado(coordinadorId, estado, pageable);
        } else {
            page = cartaRepository.findByApadrinadoCoordinadorId(coordinadorId, pageable);
        }

        return PaginationHelper.convertToPagedResponse(page, this::mapToDTO);
    }

    // ==================== MÉTODOS DE PAGINACIÓN ====================

    @Transactional(readOnly = true)
    public PagedResponseDTO<CartaResponseDTO> listarTodasPaginado(int pagina, int tamano, String sortBy, String sortDir) {
        Sort sort = sortDir.equalsIgnoreCase("desc") ? Sort.by(sortBy).descending() : Sort.by(sortBy).ascending();
        Pageable pageable = PageRequest.of(pagina, tamano, sort);
        Page<Carta> page = cartaRepository.findAll(pageable);
        return PaginationHelper.convertToPagedResponse(page, this::mapToDTO);
    }

    @Transactional(readOnly = true)
    public PagedResponseDTO<CartaResponseDTO> listarPorApadrinadoPaginado(
            Long apadrinadoId, EstadoCarta estado, String titulo, int pagina, int tamano, String sortBy, String sortDir) {
        Sort sort = sortDir.equalsIgnoreCase("desc") ? Sort.by(sortBy).descending() : Sort.by(sortBy).ascending();
        Pageable pageable = PageRequest.of(pagina, tamano, sort);
        Page<Carta> page;

        if (estado != null && titulo != null && !titulo.isEmpty()) {
            page = cartaRepository.findByApadrinadoIdAndEstadoAndTituloContainingIgnoreCase(apadrinadoId, estado, titulo, pageable);
        } else if (estado != null) {
            page = cartaRepository.findByApadrinadoIdAndEstado(apadrinadoId, estado, pageable);
        } else {
            page = cartaRepository.findByApadrinadoId(apadrinadoId, pageable);
        }

        return PaginationHelper.convertToPagedResponse(page, this::mapToDTO);
    }

    @Transactional(readOnly = true)
    public PagedResponseDTO<CartaResponseDTO> listarPorExpedientePaginado(
            Long expedienteId, EstadoCarta estado, String titulo, int pagina, int tamano, String sortBy, String sortDir) {
        Sort sort = sortDir.equalsIgnoreCase("desc") ? Sort.by(sortBy).descending() : Sort.by(sortBy).ascending();
        Pageable pageable = PageRequest.of(pagina, tamano, sort);
        Page<Carta> page;

        if (estado != null && titulo != null && !titulo.isEmpty()) {
            page = cartaRepository.findByExpedienteIdAndEstadoAndTituloContainingIgnoreCase(expedienteId, estado, titulo, pageable);
        } else if (estado != null) {
            page = cartaRepository.findByEstado(estado, pageable);
        } else {
            page = cartaRepository.findByExpedienteId(expedienteId, pageable);
        }

        return PaginationHelper.convertToPagedResponse(page, this::mapToDTO);
    }

    @Transactional
    public CartaResponseDTO crear(CartaRequestDTO request, Long usuarioId) {
        Apadrinado apadrinado = apadrinadoRepository.findById(request.getApadrinadoId())
                .orElseThrow(() -> new RuntimeException("Apadrinado no encontrado con id: " + request.getApadrinadoId()));

        Usuario usuario = usuarioRepository.findById(usuarioId)
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado con id: " + usuarioId));

        Expediente expediente = expedienteRepository.findByApadrinadoId(apadrinado.getId())
                .orElseThrow(() -> new RuntimeException("No existe expediente para el apadrinado con id: " + apadrinado.getId()));

        Actividad actividad = null;
        if (request.getActividadId() != null) {
            actividad = actividadRepository.findById(request.getActividadId())
                    .orElseThrow(() -> new RuntimeException("Actividad no encontrada con id: " + request.getActividadId()));
        }

        Carta carta = Carta.builder()
                .titulo(request.getTitulo())
                .contenido(request.getContenido())
                .tipoCarta(request.getTipoCarta() != null ? Carta.TipoCarta.valueOf(request.getTipoCarta()) : Carta.TipoCarta.GENERAL)
                .estado(EstadoCarta.BORRADOR)
                .expediente(expediente)
                .actividad(actividad)
                .apadrinado(apadrinado)
                .escritoPor(usuario)
                .observaciones(request.getObservaciones())
                .build();

        return mapToDTO(cartaRepository.save(carta));
    }

    @Transactional
    public CartaResponseDTO actualizar(Long id, CartaRequestDTO request) {
        Carta carta = cartaRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Carta no encontrada con id: " + id));

        if (request.getTitulo() != null) carta.setTitulo(request.getTitulo());
        if (request.getContenido() != null) carta.setContenido(request.getContenido());
        if (request.getTipoCarta() != null) carta.setTipoCarta(Carta.TipoCarta.valueOf(request.getTipoCarta()));
        if (request.getObservaciones() != null) carta.setObservaciones(request.getObservaciones());

        if (request.getActividadId() != null) {
            Actividad actividad = actividadRepository.findById(request.getActividadId())
                    .orElseThrow(() -> new RuntimeException("Actividad no encontrada con id: " + request.getActividadId()));
            carta.setActividad(actividad);
        }

        return mapToDTO(cartaRepository.save(carta));
    }

    @Transactional
    public CartaResponseDTO enviarCarta(Long id) {
        Carta carta = cartaRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Carta no encontrada con id: " + id));

        carta.setEstado(EstadoCarta.ENVIADA);
        carta.setFechaEnvio(LocalDateTime.now());

        return mapToDTO(cartaRepository.save(carta));
    }

    @Transactional
    public CartaResponseDTO cambiarEstado(Long id, EstadoCarta estado) {
        Carta carta = cartaRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Carta no encontrada con id: " + id));

        carta.setEstado(estado);

        return mapToDTO(cartaRepository.save(carta));
    }

    @Transactional
    public void eliminar(Long id) {
        if (!cartaRepository.existsById(id)) {
            throw new RuntimeException("Carta no encontrada con id: " + id);
        }
        cartaRepository.deleteById(id);
    }

    private CartaResponseDTO mapToDTO(Carta carta) {
        return CartaResponseDTO.builder()
                .id(carta.getId())
                .titulo(carta.getTitulo())
                .contenido(carta.getContenido())
                .fechaCreacion(carta.getFechaCreacion())
                .fechaEnvio(carta.getFechaEnvio())
                .tipoCarta(carta.getTipoCarta())
                .estado(carta.getEstado())
                .expedienteId(carta.getExpediente() != null ? carta.getExpediente().getId() : null)
                .actividadId(carta.getActividad() != null ? carta.getActividad().getId() : null)
                .apadrinadoId(carta.getApadrinado() != null ? carta.getApadrinado().getId() : null)
                .apadrinadoNombre(carta.getApadrinado() != null && carta.getApadrinado().getUsuario() != null
                        ? carta.getApadrinado().getUsuario().getNombre() + " " + carta.getApadrinado().getUsuario().getApellido()
                        : null)
                .escritoPorId(carta.getEscritoPor() != null ? carta.getEscritoPor().getId() : null)
                .escritoPorNombre(carta.getEscritoPor() != null
                        ? carta.getEscritoPor().getNombre() + " " + carta.getEscritoPor().getApellido()
                        : null)
                .observaciones(carta.getObservaciones())
                .build();
    }
}
