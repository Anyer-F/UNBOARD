package com.example.backend.service;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.dto.ComunidadRequestDTO;
import com.example.backend.dto.ComunidadResponseDTO;
import com.example.backend.entity.Comunidad;
import com.example.backend.repository.ComunidadRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class ComunidadService {

    private final ComunidadRepository comunidadRepository;

    @Transactional(readOnly = true)
    public List<ComunidadResponseDTO> listarTodas() {
        return comunidadRepository.findAll().stream()
                .map(this::convertirAResponseDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public ComunidadResponseDTO obtenerPorId(Long id) {
        Comunidad comunidad = comunidadRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Comunidad no encontrada con ID: " + id));
        return convertirAResponseDTO(comunidad);
    }

    @Transactional
    public ComunidadResponseDTO crear(ComunidadRequestDTO dto) {
        if (dto.getNombre() == null || dto.getNombre().isBlank()) {
            throw new RuntimeException("El nombre de la comunidad es obligatorio.");
        }

        if (comunidadRepository.existsByNombreIgnoreCase(dto.getNombre().trim())) {
            throw new RuntimeException("Ya existe una comunidad con el nombre: " + dto.getNombre());
        }

        Comunidad comunidad = Comunidad.builder()
                .nombre(dto.getNombre().trim())
                .municipio(dto.getMunicipio() != null ? dto.getMunicipio().trim() : null)
                .departamento(dto.getDepartamento() != null ? dto.getDepartamento().trim() : null)
                .build();

        Comunidad guardada = comunidadRepository.save(comunidad);
        return convertirAResponseDTO(guardada);
    }

    @Transactional
    public ComunidadResponseDTO actualizar(Long id, ComunidadRequestDTO dto) {
        Comunidad comunidad = comunidadRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Comunidad no encontrada con ID: " + id));

        if (dto.getNombre() != null && !dto.getNombre().isBlank()) {
            String nuevoNombre = dto.getNombre().trim();
            if (!nuevoNombre.equalsIgnoreCase(comunidad.getNombre()) && comunidadRepository.existsByNombreIgnoreCase(nuevoNombre)) {
                throw new RuntimeException("Ya existe otra comunidad con el nombre: " + nuevoNombre);
            }
            comunidad.setNombre(nuevoNombre);
        }

        if (dto.getMunicipio() != null) {
            comunidad.setMunicipio(dto.getMunicipio().trim());
        }

        if (dto.getDepartamento() != null) {
            comunidad.setDepartamento(dto.getDepartamento().trim());
        }

        Comunidad actualizada = comunidadRepository.save(comunidad);
        return convertirAResponseDTO(actualizada);
    }

    @Transactional
    public void eliminar(Long id) {
        if (!comunidadRepository.existsById(id)) {
            throw new RuntimeException("Comunidad no encontrada con ID: " + id);
        }
        comunidadRepository.deleteById(id);
    }

    public ComunidadResponseDTO convertirAResponseDTO(Comunidad comunidad) {
        if (comunidad == null) {
            return null;
        }
        return ComunidadResponseDTO.builder()
                .id(comunidad.getId())
                .nombre(comunidad.getNombre())
                .municipio(comunidad.getMunicipio())
                .departamento(comunidad.getDepartamento())
                .build();
    }
}
