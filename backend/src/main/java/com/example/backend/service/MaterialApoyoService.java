package com.example.backend.service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.core.io.Resource;
import org.springframework.http.MediaTypeFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.example.backend.config.AccesoDenegadoException;
import com.example.backend.dto.MaterialApoyoResponseDTO;
import com.example.backend.entity.Comunidad;
import com.example.backend.entity.Coordinador;
import com.example.backend.entity.MaterialApoyo;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ComunidadRepository;
import com.example.backend.repository.MaterialApoyoRepository;
import com.example.backend.service.SeguridadService;

import lombok.RequiredArgsConstructor;

/**
 * Servicio de material de apoyo.
 * El coordinador comparte material con los apadrinados
 * de su comunidad; el apadrinado solo ve y descarga el
 * material de su propia comunidad.
 */
@Service
@RequiredArgsConstructor
public class MaterialApoyoService {

    private final MaterialApoyoRepository materialApoyoRepository;
    private final ComunidadRepository comunidadRepository;
    private final FileStorageService fileStorageService;
    private final SeguridadService seguridadService;

    @Transactional
    public MaterialApoyoResponseDTO subir(MultipartFile file, String titulo, String descripcion,
            Long comunidadId) {
        seguridadService.requerirCoordinador();

        if (file == null || file.isEmpty()) {
            throw new RuntimeException("El archivo proporcionado está vacío o no fue enviado.");
        }
        if (titulo == null || titulo.isBlank()) {
            throw new RuntimeException("El título del material es obligatorio.");
        }

        Coordinador coordinador = seguridadService.coordinadorActual();
        Comunidad comunidad;
        if (comunidadId != null) {
            // FASE F: el coordinador elige a cuál de sus comunidades
            // dirigir el material de apoyo
            seguridadService.verificarComunidadPropia(comunidadId);
            comunidad = comunidadRepository.findById(comunidadId)
                    .orElseThrow(() -> new RuntimeException(
                            "Comunidad no encontrada con ID: " + comunidadId));
        } else {
            if (coordinador == null || coordinador.getComunidad() == null) {
                throw new AccesoDenegadoException("No tiene una comunidad asignada.");
            }
            comunidad = coordinador.getComunidad();
        }
        Usuario subidoPor = seguridadService.usuarioActual();

        // Guardar archivo físico en disco
        String storedFileName = fileStorageService.storeFile(file);
        String relativePath = "uploads/" + storedFileName;
        String originalFileName = file.getOriginalFilename() != null ? file.getOriginalFilename() : "material";

        // Determinar tipo MIME exacto
        String mimeType = file.getContentType();
        if (mimeType == null || mimeType.isBlank() || mimeType.equals("application/octet-stream")) {
            mimeType = MediaTypeFactory.getMediaType(originalFileName)
                    .map(org.springframework.http.MediaType::toString)
                    .orElse("application/octet-stream");
        }

        MaterialApoyo material = MaterialApoyo.builder()
                .titulo(titulo.trim())
                .descripcion(descripcion)
                .nombreOriginal(originalFileName)
                .nombreAlmacenado(storedFileName)
                .rutaArchivo(relativePath)
                .tipoMime(mimeType)
                .tamanioBytes(file.getSize())
                .fechaSubida(LocalDateTime.now())
                .comunidad(comunidad)
                .coordinador(coordinador)
                .subidoPor(subidoPor)
                .build();

        return convertirAResponseDTO(materialApoyoRepository.save(material));
    }

    /**
     * Lista el material de la comunidad del usuario autenticado
     * (coordinador o apadrinado), filtrado en el servidor.
     * FASE F: el coordinador ve el material de TODAS sus comunidades.
     */
    @Transactional(readOnly = true)
    public List<MaterialApoyoResponseDTO> listarMaterialDeMiComunidad() {
        Usuario usuario = seguridadService.usuarioActual();
        if (seguridadService.esCoordinador(usuario)) {
            Set<Long> idsComunidades = seguridadService.comunidadesDelCoordinador();
            if (idsComunidades.isEmpty()) {
                throw new AccesoDenegadoException("No tiene una comunidad asignada.");
            }
            return materialApoyoRepository
                    .findByComunidadIdInOrderByFechaSubidaDesc(new ArrayList<>(idsComunidades))
                    .stream()
                    .map(this::convertirAResponseDTO)
                    .collect(Collectors.toList());
        } else if (seguridadService.esApadrinado(usuario)) {
            var apadrinado = seguridadService.apadrinadoActual();
            if (apadrinado == null || apadrinado.getComunidad() == null) {
                throw new AccesoDenegadoException("No tiene una comunidad asignada.");
            }
            return materialApoyoRepository
                    .findByComunidadIdOrderByFechaSubidaDesc(apadrinado.getComunidad().getId())
                    .stream()
                    .map(this::convertirAResponseDTO)
                    .collect(Collectors.toList());
        }
        throw new AccesoDenegadoException("Acceso denegado.");
    }

    /**
     * Lista el material de una comunidad accesible para el usuario actual.
     */
    @Transactional(readOnly = true)
    public List<MaterialApoyoResponseDTO> listarPorComunidad(Long comunidadId) {
        seguridadService.verificarComunidadAccesible(comunidadId);
        return materialApoyoRepository.findByComunidadIdOrderByFechaSubidaDesc(comunidadId).stream()
                .map(this::convertirAResponseDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public MaterialApoyo obtenerEntidad(Long id) {
        return materialApoyoRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Material de apoyo no encontrado con ID: " + id));
    }

    @Transactional(readOnly = true)
    public MaterialApoyoResponseDTO obtenerPorId(Long id) {
        return convertirAResponseDTO(obtenerEntidad(id));
    }

    @Transactional(readOnly = true)
    public Resource cargarArchivoComoRecurso(Long id) {
        MaterialApoyo material = obtenerEntidad(id);
        return fileStorageService.loadFileAsResource(material.getNombreAlmacenado());
    }

    /**
     * Solo el coordinador responsable de la comunidad puede eliminar el material.
     */
    @Transactional
    public void eliminar(Long id) {
        seguridadService.requerirCoordinador();
        MaterialApoyo material = obtenerEntidad(id);
        seguridadService.verificarComunidadPropia(material.getComunidad().getId());
        fileStorageService.deleteFile(material.getNombreAlmacenado());
        materialApoyoRepository.delete(material);
    }

    public MaterialApoyoResponseDTO convertirAResponseDTO(MaterialApoyo material) {
        String comunidadNombre = null;
        Long comunidadId = null;
        if (material.getComunidad() != null) {
            comunidadId = material.getComunidad().getId();
            comunidadNombre = material.getComunidad().getNombre();
        }

        Long coordinadorId = null;
        if (material.getCoordinador() != null) {
            coordinadorId = material.getCoordinador().getId();
        }

        Long subidoPorId = null;
        String subidoPorNombre = null;
        if (material.getSubidoPor() != null) {
            subidoPorId = material.getSubidoPor().getId();
            subidoPorNombre = material.getSubidoPor().getNombre();
        }

        return MaterialApoyoResponseDTO.builder()
                .id(material.getId())
                .titulo(material.getTitulo())
                .descripcion(material.getDescripcion())
                .nombreOriginal(material.getNombreOriginal())
                .urlDescarga("/api/material-apoyo/" + material.getId() + "/descargar")
                .tipoMime(material.getTipoMime())
                .tamanioBytes(material.getTamanioBytes())
                .fechaSubida(material.getFechaSubida())
                .comunidadId(comunidadId)
                .comunidadNombre(comunidadNombre)
                .coordinadorId(coordinadorId)
                .subidoPorUsuarioId(subidoPorId)
                .subidoPorNombre(subidoPorNombre)
                .build();
    }
}
