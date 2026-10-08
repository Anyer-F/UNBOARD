package com.example.backend.service;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.config.AccesoDenegadoException;
import com.example.backend.dto.CodigoAccesoRequestDTO;
import com.example.backend.dto.CodigoAccesoResponseDTO;
import com.example.backend.entity.CodigoAcceso;
import com.example.backend.entity.Comunidad;
import com.example.backend.entity.Coordinador;
import com.example.backend.repository.CodigoAccesoRepository;
import com.example.backend.repository.ComunidadRepository;

import lombok.RequiredArgsConstructor;

/**
 * Servicio de códigos de acceso a comunidades.
 * Solo el coordinador responsable de una comunidad puede
 * generar, listar y desactivar sus códigos.
 */
@Service
@RequiredArgsConstructor
public class CodigoAccesoService {

    private final CodigoAccesoRepository codigoAccesoRepository;
    private final ComunidadRepository comunidadRepository;
    private final SeguridadService seguridadService;

    private static final String ALFANUMERICO = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    private static final int LONGITUD_CODIGO = 8;
    private static final SecureRandom RANDOM = new SecureRandom();

    @Transactional
    public CodigoAccesoResponseDTO generar(Long comunidadId, CodigoAccesoRequestDTO request) {
        seguridadService.requerirCoordinador();
        seguridadService.verificarComunidadPropia(comunidadId);

        Comunidad comunidad = comunidadRepository.findById(comunidadId)
                .orElseThrow(() -> new RuntimeException("Comunidad no encontrada con ID: " + comunidadId));
        Coordinador coordinador = seguridadService.coordinadorActual();

        // Generar código único
        String codigo;
        do {
            codigo = generarCodigoAleatorio();
        } while (codigoAccesoRepository.findByCodigo(codigo).isPresent());

        CodigoAcceso nuevo = CodigoAcceso.builder()
                .codigo(codigo)
                .comunidad(comunidad)
                .coordinador(coordinador)
                .activo(true)
                .fechaCreacion(LocalDateTime.now())
                .fechaExpiracion(request.getFechaExpiracion())
                .maxUsos(request.getMaxUsos())
                .usos(0)
                .descripcion(request.getDescripcion())
                .build();

        return convertirAResponseDTO(codigoAccesoRepository.save(nuevo));
    }

    @Transactional(readOnly = true)
    public List<CodigoAccesoResponseDTO> listarPorComunidad(Long comunidadId) {
        seguridadService.requerirCoordinador();
        seguridadService.verificarComunidadPropia(comunidadId);
        return codigoAccesoRepository.findByComunidadId(comunidadId).stream()
                .map(this::convertirAResponseDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public void desactivar(Long id) {
        seguridadService.requerirCoordinador();
        CodigoAcceso codigo = codigoAccesoRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Código de acceso no encontrado con ID: " + id));
        seguridadService.verificarComunidadPropia(codigo.getComunidad().getId());
        codigo.setActivo(false);
        codigoAccesoRepository.save(codigo);
    }

    /**
     * Valida un código de acceso para una comunidad.
     * Debe existir, pertenecer a la comunidad, estar activo,
     * no haber expirado y no haber agotado sus usos.
     */
    @Transactional(readOnly = true)
    public CodigoAcceso validarCodigo(Long comunidadId, String codigoTexto) {
        if (codigoTexto == null || codigoTexto.isBlank()) {
            throw new RuntimeException("El código de acceso es obligatorio.");
        }
        CodigoAcceso codigo = codigoAccesoRepository.findByCodigo(codigoTexto.trim().toUpperCase())
                .orElseThrow(() -> new RuntimeException("Código de acceso inválido."));

        if (!codigo.getComunidad().getId().equals(comunidadId)) {
            throw new RuntimeException("El código de acceso no pertenece a la comunidad indicada.");
        }
        if (!Boolean.TRUE.equals(codigo.getActivo())) {
            throw new RuntimeException("El código de acceso ya no está activo.");
        }
        if (codigo.getFechaExpiracion() != null
                && codigo.getFechaExpiracion().isBefore(LocalDateTime.now())) {
            throw new RuntimeException("El código de acceso ha expirado.");
        }
        if (codigo.getMaxUsos() != null && codigo.getUsos() >= codigo.getMaxUsos()) {
            throw new RuntimeException("El código de acceso ha alcanzado el límite de usos.");
        }
        return codigo;
    }

    /**
     * Registra un uso del código. Al alcanzar el límite,
     * el código se desactiva automáticamente.
     */
    @Transactional
    public void registrarUso(CodigoAcceso codigo) {
        codigo.setUsos(codigo.getUsos() + 1);
        if (codigo.getMaxUsos() != null && codigo.getUsos() >= codigo.getMaxUsos()) {
            codigo.setActivo(false);
        }
        codigoAccesoRepository.save(codigo);
    }

    private String generarCodigoAleatorio() {
        StringBuilder sb = new StringBuilder(LONGITUD_CODIGO);
        for (int i = 0; i < LONGITUD_CODIGO; i++) {
            sb.append(ALFANUMERICO.charAt(RANDOM.nextInt(ALFANUMERICO.length())));
        }
        return sb.toString();
    }

    private CodigoAccesoResponseDTO convertirAResponseDTO(CodigoAcceso codigo) {
        return CodigoAccesoResponseDTO.builder()
                .id(codigo.getId())
                .codigo(codigo.getCodigo())
                .comunidadId(codigo.getComunidad().getId())
                .comunidadNombre(codigo.getComunidad().getNombre())
                .coordinadorId(codigo.getCoordinador().getId())
                .activo(codigo.getActivo())
                .fechaCreacion(codigo.getFechaCreacion())
                .fechaExpiracion(codigo.getFechaExpiracion())
                .maxUsos(codigo.getMaxUsos())
                .usos(codigo.getUsos())
                .descripcion(codigo.getDescripcion())
                .build();
    }
}
