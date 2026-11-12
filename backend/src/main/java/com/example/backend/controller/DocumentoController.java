package com.example.backend.controller;

import java.nio.charset.StandardCharsets;
import java.util.List;

import org.springframework.core.io.Resource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.MediaTypeFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.backend.dto.DocumentoResponseDTO;
import com.example.backend.entity.Documento;
import com.example.backend.entity.TipoDocumento;
import com.example.backend.service.DocumentoService;
import com.example.backend.service.SeguridadService;

import lombok.RequiredArgsConstructor;

/**
 * Consulta y descarga de documentos. Los archivos se suben a través de
 * las actividades (material del coordinador) y de las entregas
 * (archivos del apadrinado).
 */
@RestController
@RequestMapping("/api/documentos")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class DocumentoController {

    private final DocumentoService documentoService;
    private final SeguridadService seguridadService;

    @GetMapping("/{id}")
    public ResponseEntity<DocumentoResponseDTO> obtenerPorId(@PathVariable Long id) {
        seguridadService.verificarDocumentoAccesible(id);
        return ResponseEntity.ok(documentoService.obtenerPorId(id));
    }

    @GetMapping("/{id}/descargar")
    public ResponseEntity<Resource> descargar(@PathVariable Long id) {
        return archivo(id, false);
    }

    @GetMapping("/{id}/ver")
    public ResponseEntity<Resource> ver(@PathVariable Long id) {
        return archivo(id, true);
    }

    /**
     * Gestión documental (coordinador): documentos de un apadrinado
     * clasificados por tipo, actividad y estado.
     */
    @GetMapping("/apadrinado/{apadrinadoId}")
    public ResponseEntity<List<DocumentoResponseDTO>> listarPorApadrinado(
            @PathVariable Long apadrinadoId,
            @RequestParam(value = "tipo", required = false) TipoDocumento tipo,
            @RequestParam(value = "actividadId", required = false) Long actividadId,
            @RequestParam(value = "estado", required = false) String estado) {
        seguridadService.verificarApadrinadoDeMiComunidad(apadrinadoId);
        return ResponseEntity.ok(documentoService.listarPorApadrinado(apadrinadoId, tipo, actividadId, estado));
    }

    private ResponseEntity<Resource> archivo(Long id, boolean enLinea) {
        Documento documento = seguridadService.verificarDocumentoAccesible(id);
        Resource resource = documentoService.cargarArchivoComoRecurso(id);
        String contentType = documento.getTipoMime();
        if (contentType == null || contentType.isBlank() || contentType.equalsIgnoreCase("application/octet-stream")) {
            contentType = MediaTypeFactory.getMediaType(documento.getNombreOriginal())
                    .map(MediaType::toString)
                    .orElse("application/octet-stream");
        }
        ContentDisposition disposicion = (enLinea ? ContentDisposition.inline() : ContentDisposition.attachment())
                .filename(documento.getNombreOriginal(), StandardCharsets.UTF_8)
                .build();
        var respuesta = ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(contentType))
                .header(HttpHeaders.CONTENT_DISPOSITION, disposicion.toString())
                .header(HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS, HttpHeaders.CONTENT_DISPOSITION);
        if (enLinea) {
            respuesta.header(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate");
        }
        try {
            long largo = resource.contentLength();
            if (largo > 0) {
                respuesta.contentLength(largo);
            }
        } catch (Exception ignored) {
            // longitud desconocida
        }
        return respuesta.body(resource);
    }
}
