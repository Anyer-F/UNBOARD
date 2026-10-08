package com.example.backend.controller;

import java.nio.charset.StandardCharsets;
import java.util.List;

import org.springframework.core.io.Resource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.example.backend.dto.MaterialApoyoResponseDTO;
import com.example.backend.service.MaterialApoyoService;
import com.example.backend.service.SeguridadService;

import lombok.RequiredArgsConstructor;

/**
 * Material de apoyo compartido por el coordinador con
 * los apadrinados de su comunidad.
 * - Coordinador: sube, lista y elimina el material de su comunidad.
 * - Apadrinado: lista, consulta, descarga y ve el material de su comunidad.
 */
@RestController
@RequestMapping("/api/material-apoyo")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class MaterialApoyoController {

    private final MaterialApoyoService materialApoyoService;
    private final SeguridadService seguridadService;

    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<MaterialApoyoResponseDTO> subirMaterial(
            @RequestParam("file") MultipartFile file,
            @RequestParam("titulo") String titulo,
            @RequestParam(value = "descripcion", required = false) String descripcion,
            @RequestParam(value = "comunidadId", required = false) Long comunidadId) {
        MaterialApoyoResponseDTO creado = materialApoyoService.subir(file, titulo, descripcion, comunidadId);
        return ResponseEntity.status(org.springframework.http.HttpStatus.CREATED).body(creado);
    }

    /**
     * Lista el material de la comunidad del usuario autenticado.
     */
    @GetMapping
    public ResponseEntity<List<MaterialApoyoResponseDTO>> listarDeMiComunidad() {
        return ResponseEntity.ok(materialApoyoService.listarMaterialDeMiComunidad());
    }

    /**
     * Lista el material de una comunidad accesible para el usuario actual.
     */
    @GetMapping("/comunidad/{comunidadId}")
    public ResponseEntity<List<MaterialApoyoResponseDTO>> listarPorComunidad(@PathVariable Long comunidadId) {
        return ResponseEntity.ok(materialApoyoService.listarPorComunidad(comunidadId));
    }

    @GetMapping("/{id}")
    public ResponseEntity<MaterialApoyoResponseDTO> obtenerPorId(@PathVariable Long id) {
        seguridadService.verificarMaterialAccesible(id);
        return ResponseEntity.ok(materialApoyoService.obtenerPorId(id));
    }

    @GetMapping("/{id}/descargar")
    public ResponseEntity<Resource> descargarArchivo(@PathVariable Long id) {
        seguridadService.verificarMaterialAccesible(id);
        var material = materialApoyoService.obtenerEntidad(id);
        Resource resource = materialApoyoService.cargarArchivoComoRecurso(id);

        String contentType = material.getTipoMime();
        if (contentType == null || contentType.isBlank()
                || contentType.equalsIgnoreCase("application/octet-stream")) {
            contentType = org.springframework.http.MediaTypeFactory.getMediaType(material.getNombreOriginal())
                    .map(MediaType::toString)
                    .orElse("application/octet-stream");
        }

        ContentDisposition contentDisposition = ContentDisposition.attachment()
                .filename(material.getNombreOriginal(), StandardCharsets.UTF_8)
                .build();

        var responseBuilder = ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(contentType))
                .header(HttpHeaders.CONTENT_DISPOSITION, contentDisposition.toString())
                .header(HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS, HttpHeaders.CONTENT_DISPOSITION);

        try {
            long contentLength = resource.contentLength();
            if (contentLength > 0) {
                responseBuilder.contentLength(contentLength);
            }
        } catch (Exception ignored) {}

        return responseBuilder.body(resource);
    }

    @GetMapping("/{id}/ver")
    public ResponseEntity<Resource> verArchivo(@PathVariable Long id) {
        seguridadService.verificarMaterialAccesible(id);
        var material = materialApoyoService.obtenerEntidad(id);
        Resource resource = materialApoyoService.cargarArchivoComoRecurso(id);

        String contentType = material.getTipoMime();
        if (contentType == null || contentType.isBlank()
                || contentType.equalsIgnoreCase("application/octet-stream")) {
            contentType = org.springframework.http.MediaTypeFactory.getMediaType(material.getNombreOriginal())
                    .map(MediaType::toString)
                    .orElse("application/octet-stream");
        }

        ContentDisposition contentDisposition = ContentDisposition.inline()
                .filename(material.getNombreOriginal(), StandardCharsets.UTF_8)
                .build();

        var responseBuilder = ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(contentType))
                .header(HttpHeaders.CONTENT_DISPOSITION, contentDisposition.toString())
                .header(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate")
                .header(HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS, HttpHeaders.CONTENT_DISPOSITION);

        try {
            long contentLength = resource.contentLength();
            if (contentLength > 0) {
                responseBuilder.contentLength(contentLength);
            }
        } catch (Exception ignored) {}

        return responseBuilder.body(resource);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        materialApoyoService.eliminar(id);
        return ResponseEntity.noContent().build();
    }
}
