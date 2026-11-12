package com.example.backend.service;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.dto.ModuloRequestDTO;
import com.example.backend.dto.ModuloResponseDTO;
import com.example.backend.entity.Actividad;
import com.example.backend.entity.Comunidad;
import com.example.backend.entity.EntidadHistorial;
import com.example.backend.entity.Modulo;
import com.example.backend.repository.ActividadRepository;
import com.example.backend.repository.ComunidadRepository;
import com.example.backend.repository.ModuloRepository;

import lombok.RequiredArgsConstructor;

/**
 * Módulos de la comunidad.
 *
 * - Al crearse una comunidad se crea el Módulo 1 (universal).
 * - Mientras exista un solo módulo, las actividades van a él sin elegirlo.
 * - Solo se eliminan módulos sin actividades; la comunidad conserva
 *   siempre al menos un módulo.
 */
@Service
@RequiredArgsConstructor
public class ModuloService {

    public static final String NOMBRE_MODULO_1 = "Módulo 1";

    private final ModuloRepository moduloRepository;
    private final ComunidadRepository comunidadRepository;
    private final ActividadRepository actividadRepository;
    private final SeguridadService seguridadService;
    private final HistorialActividadService historialService;
    private final ConvertidorDTO convertidor;

    /** Crea el Módulo 1 si la comunidad aún no tiene módulos. */
    @Transactional
    public Modulo asegurarModuloInicial(Comunidad comunidad) {
        return moduloRepository.findFirstByComunidadIdOrderByOrdenAscIdAsc(comunidad.getId())
                .orElseGet(() -> moduloRepository.save(Modulo.builder()
                        .comunidad(comunidad)
                        .nombre(NOMBRE_MODULO_1)
                        .descripcion("Módulo general de la comunidad")
                        .orden(1)
                        .build()));
    }

    @Transactional(readOnly = true)
    public List<ModuloResponseDTO> listar(Long comunidadId) {
        seguridadService.verificarComunidadAccesible(comunidadId);
        return moduloRepository.findByComunidadIdOrderByOrdenAscIdAsc(comunidadId).stream()
                .map(convertidor::modulo)
                .collect(Collectors.toList());
    }

    @Transactional
    public ModuloResponseDTO crear(Long comunidadId, ModuloRequestDTO dto) {
        seguridadService.verificarComunidadPropia(comunidadId);
        Comunidad comunidad = comunidadRepository.findById(comunidadId)
                .orElseThrow(() -> new RuntimeException("Comunidad no encontrada con ID: " + comunidadId));
        asegurarModuloInicial(comunidad);
        String nombre = obligatorio(dto.getNombre());
        List<Modulo> existentes = moduloRepository.findByComunidadIdOrderByOrdenAscIdAsc(comunidadId);
        int orden = existentes.isEmpty() ? 1 : existentes.get(existentes.size() - 1).getOrden() + 1;
        Modulo modulo = moduloRepository.save(Modulo.builder()
                .comunidad(comunidad)
                .nombre(nombre)
                .descripcion(limpiar(dto.getDescripcion()))
                .orden(orden)
                .build());
        if (dto.getOrden() != null) {
            moverAPosicion(modulo, dto.getOrden());
        }
        historialService.registrar(EntidadHistorial.MODULO, modulo.getId(), modulo.getNombre(), null,
                comunidad, null, "MÓDULO CREADO", null, seguridadService.usuarioActual());
        return convertidor.modulo(modulo);
    }

    @Transactional
    public ModuloResponseDTO actualizar(Long moduloId, ModuloRequestDTO dto) {
        Modulo modulo = cargarPropio(moduloId);
        String anterior = modulo.getNombre();
        if (dto.getNombre() != null) {
            modulo.setNombre(obligatorio(dto.getNombre()));
        }
        if (dto.getDescripcion() != null) {
            modulo.setDescripcion(limpiar(dto.getDescripcion()));
        }
        moduloRepository.save(modulo);
        if (dto.getOrden() != null) {
            moverAPosicion(modulo, dto.getOrden());
        }
        historialService.registrar(EntidadHistorial.MODULO, modulo.getId(), modulo.getNombre(), null,
                modulo.getComunidad(), null, "MÓDULO EDITADO",
                anterior.equals(modulo.getNombre()) ? null : "Antes: " + anterior,
                seguridadService.usuarioActual());
        return convertidor.modulo(modulo);
    }

    /** Reordena los módulos de la comunidad según la lista de IDs recibida. */
    @Transactional
    public List<ModuloResponseDTO> reordenar(Long comunidadId, List<Long> ids) {
        seguridadService.verificarComunidadPropia(comunidadId);
        List<Modulo> modulos = moduloRepository.findByComunidadIdOrderByOrdenAscIdAsc(comunidadId);
        if (ids == null || ids.size() != modulos.size()
                || !new HashSet<>(ids).equals(modulos.stream().map(Modulo::getId).collect(Collectors.toSet()))) {
            throw new RuntimeException("Debe indicar el nuevo orden de todos los módulos de la comunidad.");
        }
        for (int i = 0; i < ids.size(); i++) {
            Long id = ids.get(i);
            Modulo m = modulos.stream().filter(x -> x.getId().equals(id)).findFirst().orElseThrow();
            m.setOrden(i + 1);
        }
        moduloRepository.saveAll(modulos);
        historialService.registrar(EntidadHistorial.MODULO, null, "Orden de módulos", null,
                modulos.get(0).getComunidad(), null, "MÓDULOS REORDENADOS", null, seguridadService.usuarioActual());
        return listar(comunidadId);
    }

    @Transactional
    public void eliminar(Long moduloId) {
        Modulo modulo = cargarPropio(moduloId);
        if (moduloRepository.countByComunidadId(modulo.getComunidad().getId()) <= 1) {
            throw new RuntimeException("La comunidad debe tener al menos un módulo.");
        }
        if (actividadRepository.countByModuloId(moduloId) > 0) {
            throw new RuntimeException(
                    "El módulo tiene actividades. Muévalas a otro módulo antes de eliminarlo.");
        }
        Long comunidadId = modulo.getComunidad().getId();
        historialService.registrar(EntidadHistorial.MODULO, modulo.getId(), modulo.getNombre(), null,
                modulo.getComunidad(), null, "MÓDULO ELIMINADO", null, seguridadService.usuarioActual());
        moduloRepository.delete(modulo);
        renumerar(comunidadId);
    }

    /** Mueve una actividad a otro módulo de la misma comunidad. */
    @Transactional
    public void moverActividad(Long actividadId, Long moduloDestinoId) {
        Actividad actividad = seguridadService.verificarActividadPropia(actividadId);
        Modulo destino = cargarPropio(moduloDestinoId);
        if (!destino.getComunidad().getId().equals(actividad.getComunidad().getId())) {
            throw new RuntimeException("El módulo destino no pertenece a la comunidad de la actividad.");
        }
        String origen = actividad.getModulo() != null ? actividad.getModulo().getNombre() : "—";
        actividad.setModulo(destino);
        actividadRepository.save(actividad);
        historialService.registrarActividad(actividad, "ACTIVIDAD MOVIDA",
                "De " + origen + " a " + destino.getNombre(), seguridadService.usuarioActual());
    }

    /**
     * Módulo para una nueva actividad: el indicado, o el único módulo de la
     * comunidad. Con varios módulos el coordinador debe elegir.
     */
    @Transactional
    public Modulo resolverModulo(Comunidad comunidad, Long moduloId) {
        Modulo inicial = asegurarModuloInicial(comunidad);
        if (moduloId == null) {
            if (moduloRepository.countByComunidadId(comunidad.getId()) > 1) {
                throw new RuntimeException("La comunidad tiene varios módulos: seleccione el módulo de la actividad.");
            }
            return inicial;
        }
        Modulo modulo = moduloRepository.findById(moduloId)
                .orElseThrow(() -> new RuntimeException("Módulo no encontrado con ID: " + moduloId));
        if (!modulo.getComunidad().getId().equals(comunidad.getId())) {
            throw new RuntimeException("El módulo no pertenece a la comunidad seleccionada.");
        }
        return modulo;
    }

    private Modulo cargarPropio(Long moduloId) {
        Modulo modulo = moduloRepository.findById(moduloId)
                .orElseThrow(() -> new RuntimeException("Módulo no encontrado con ID: " + moduloId));
        seguridadService.verificarComunidadPropia(modulo.getComunidad().getId());
        return modulo;
    }

    private void moverAPosicion(Modulo modulo, int posicion) {
        List<Modulo> lista = new ArrayList<>(
                moduloRepository.findByComunidadIdOrderByOrdenAscIdAsc(modulo.getComunidad().getId()));
        lista.removeIf(m -> m.getId().equals(modulo.getId()));
        int indice = Math.max(0, Math.min(posicion - 1, lista.size()));
        lista.add(indice, modulo);
        for (int i = 0; i < lista.size(); i++) {
            lista.get(i).setOrden(i + 1);
        }
        moduloRepository.saveAll(lista);
    }

    private void renumerar(Long comunidadId) {
        List<Modulo> lista = moduloRepository.findByComunidadIdOrderByOrdenAscIdAsc(comunidadId);
        for (int i = 0; i < lista.size(); i++) {
            lista.get(i).setOrden(i + 1);
        }
        moduloRepository.saveAll(lista);
    }

    private static String obligatorio(String nombre) {
        if (nombre == null || nombre.isBlank()) {
            throw new RuntimeException("El nombre del módulo es obligatorio.");
        }
        return nombre.trim();
    }

    private static String limpiar(String texto) {
        return texto == null || texto.isBlank() ? null : texto.trim();
    }
}
