package com.example.backend.service;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.dto.ComunidadRequestDTO;
import com.example.backend.dto.ComunidadResponseDTO;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Comunidad;
import com.example.backend.entity.Coordinador;
import com.example.backend.entity.EntidadHistorial;
import com.example.backend.entity.ModoIncorporacion;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ActividadRepository;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.ComunidadRepository;
import com.example.backend.repository.CoordinadorRepository;
import com.example.backend.repository.ModuloRepository;

import lombok.RequiredArgsConstructor;

/**
 * Comunidades: cada coordinador administra una o varias. Al crear una
 * comunidad queda bajo la responsabilidad de quien la crea y se genera
 * automáticamente su Módulo 1.
 */
@Service
@RequiredArgsConstructor
public class ComunidadService {

    private final ComunidadRepository comunidadRepository;
    private final CoordinadorRepository coordinadorRepository;
    private final ApadrinadoRepository apadrinadoRepository;
    private final ActividadRepository actividadRepository;
    private final ModuloRepository moduloRepository;
    private final ModuloService moduloService;
    private final SeguridadService seguridadService;
    private final HistorialActividadService historialService;

    /**
     * Comunidades del usuario: las que administra (coordinador) o
     * aquella a la que pertenece (apadrinado).
     */
    @Transactional(readOnly = true)
    public List<ComunidadResponseDTO> listarMias() {
        Usuario usuario = seguridadService.usuarioActual();
        List<Comunidad> comunidades = new ArrayList<>();
        if (seguridadService.esCoordinador(usuario)) {
            comunidades = comunidadRepository.findAllById(seguridadService.comunidadesDelCoordinador());
        } else if (seguridadService.esApadrinado(usuario)) {
            Apadrinado a = seguridadService.apadrinadoActual();
            if (a != null && a.getComunidad() != null) {
                comunidades = List.of(a.getComunidad());
            }
        }
        return comunidades.stream()
                .sorted((x, y) -> x.getNombre().compareToIgnoreCase(y.getNombre()))
                .map(this::convertirConTotales)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public ComunidadResponseDTO obtenerPorId(Long id) {
        seguridadService.verificarComunidadAccesible(id);
        return convertirConTotales(cargar(id));
    }

    @Transactional
    public ComunidadResponseDTO crear(ComunidadRequestDTO dto) {
        Coordinador coordinador = seguridadService.requerirCoordinadorActual();
        if (dto.getNombre() == null || dto.getNombre().isBlank()) {
            throw new RuntimeException("El nombre de la comunidad es obligatorio.");
        }
        if (comunidadRepository.existsByNombreIgnoreCase(dto.getNombre().trim())) {
            throw new RuntimeException("Ya existe una comunidad con el nombre: " + dto.getNombre().trim());
        }
        Comunidad comunidad = comunidadRepository.save(Comunidad.builder()
                .nombre(dto.getNombre().trim())
                .municipio(limpiar(dto.getMunicipio()))
                .departamento(limpiar(dto.getDepartamento()))
                .modoIncorporacion(dto.getModoIncorporacion() != null
                        ? dto.getModoIncorporacion() : ModoIncorporacion.SOLICITUD)
                .build());

        // Queda bajo la responsabilidad del coordinador que la crea
        if (coordinador.getComunidad() == null) {
            coordinador.setComunidad(comunidad);
        }
        coordinador.getComunidades().add(comunidad);
        coordinadorRepository.save(coordinador);

        moduloService.asegurarModuloInicial(comunidad);
        historialService.registrar(EntidadHistorial.COMUNIDAD, comunidad.getId(), comunidad.getNombre(), null,
                comunidad, null, "COMUNIDAD CREADA", null, coordinador.getUsuario());
        return convertirConTotales(comunidad);
    }

    @Transactional
    public ComunidadResponseDTO actualizar(Long id, ComunidadRequestDTO dto) {
        seguridadService.verificarComunidadPropia(id);
        Comunidad comunidad = cargar(id);
        if (dto.getNombre() != null && !dto.getNombre().isBlank()) {
            String nuevo = dto.getNombre().trim();
            if (!nuevo.equalsIgnoreCase(comunidad.getNombre()) && comunidadRepository.existsByNombreIgnoreCase(nuevo)) {
                throw new RuntimeException("Ya existe otra comunidad con el nombre: " + nuevo);
            }
            comunidad.setNombre(nuevo);
        }
        if (dto.getMunicipio() != null) {
            comunidad.setMunicipio(limpiar(dto.getMunicipio()));
        }
        if (dto.getDepartamento() != null) {
            comunidad.setDepartamento(limpiar(dto.getDepartamento()));
        }
        if (dto.getModoIncorporacion() != null) {
            comunidad.setModoIncorporacion(dto.getModoIncorporacion());
        }
        comunidad = comunidadRepository.save(comunidad);
        historialService.registrar(EntidadHistorial.COMUNIDAD, comunidad.getId(), comunidad.getNombre(), null,
                comunidad, null, "COMUNIDAD EDITADA", "Incorporación: " + comunidad.getModoIncorporacion(),
                seguridadService.usuarioActual());
        return convertirConTotales(comunidad);
    }

    /** Solo se elimina una comunidad sin apadrinados ni actividades. */
    @Transactional
    public void eliminar(Long id) {
        seguridadService.verificarComunidadPropia(id);
        Comunidad comunidad = cargar(id);
        if (!apadrinadoRepository.findByComunidadId(id).isEmpty()) {
            throw new RuntimeException("La comunidad tiene apadrinados y no se puede eliminar.");
        }
        if (actividadRepository.countByComunidadId(id) > 0) {
            throw new RuntimeException("La comunidad tiene actividades y no se puede eliminar.");
        }
        for (Coordinador c : coordinadorRepository.findAll()) {
            boolean cambio = c.getComunidades().removeIf(x -> x.getId().equals(id));
            if (c.getComunidad() != null && c.getComunidad().getId().equals(id)) {
                c.setComunidad(c.getComunidades().isEmpty() ? null : c.getComunidades().get(0));
                cambio = true;
            }
            if (cambio) {
                coordinadorRepository.save(c);
            }
        }
        historialService.registrar(EntidadHistorial.COMUNIDAD, id, comunidad.getNombre(), null, null, null,
                "COMUNIDAD ELIMINADA", null, seguridadService.usuarioActual());
        comunidadRepository.delete(comunidad);
    }

    private Comunidad cargar(Long id) {
        return comunidadRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Comunidad no encontrada con ID: " + id));
    }

    private ComunidadResponseDTO convertirConTotales(Comunidad c) {
        ComunidadResponseDTO dto = convertir(c, (long) apadrinadoRepository.findByComunidadId(c.getId()).size(),
                moduloRepository.countByComunidadId(c.getId()));
        coordinadorRepository.findAll().stream()
                .filter(co -> co.getComunidad() != null && co.getComunidad().getId().equals(c.getId()))
                .findFirst()
                .ifPresent(co -> dto.setCoordinadorNombre(ConvertidorDTO.nombreCompleto(co.getUsuario())));
        return dto;
    }

    public static ComunidadResponseDTO convertir(Comunidad c, Long totalApadrinados, Long totalModulos) {
        if (c == null) {
            return null;
        }
        return ComunidadResponseDTO.builder()
                .id(c.getId())
                .nombre(c.getNombre())
                .municipio(c.getMunicipio())
                .departamento(c.getDepartamento())
                .modoIncorporacion(c.getModoIncorporacion())
                .totalApadrinados(totalApadrinados)
                .totalModulos(totalModulos)
                .build();
    }

    /** Compatibilidad con servicios que convierten una comunidad sin totales. */
    public ComunidadResponseDTO convertirAResponseDTO(Comunidad comunidad) {
        return convertir(comunidad, null, null);
    }

    private static String limpiar(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
