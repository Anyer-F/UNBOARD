package com.example.backend.controller;

import java.nio.charset.StandardCharsets;
import java.util.List;

import org.springframework.core.io.Resource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.backend.dto.ExportacionResponseDTO;
import com.example.backend.entity.Exportacion;
import com.example.backend.service.ExportacionService;

import lombok.RequiredArgsConstructor;

/**
 * Descarga de los PDF / ZIP generados (guardados temporalmente en el
 * repositorio de documentos). Solo el coordinador que los generó.
 */
@RestController
@RequestMapping("/api/exportaciones")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class ExportacionController {

    private final ExportacionService exportacionService;

    @GetMapping
    public ResponseEntity<List<ExportacionResponseDTO>> listar() {
        return ResponseEntity.ok(exportacionService.listarMias());
    }

    @GetMapping("/{id}/descargar")
    public ResponseEntity<Resource> descargar(@PathVariable Long id) {
        Exportacion e = exportacionService.obtenerParaDescarga(id);
        Resource archivo = exportacionService.archivo(e);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(e.getTipoMime() != null ? e.getTipoMime() : "application/octet-stream"))
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.attachment()
                        .filename(e.getNombreArchivo(), StandardCharsets.UTF_8).build().toString())
                .header(HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS, HttpHeaders.CONTENT_DISPOSITION)
                .body(archivo);
    }
}
