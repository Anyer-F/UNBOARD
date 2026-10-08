package com.example.backend.controller;

import java.util.List;

import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
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

import com.example.backend.dto.DocumentoResponseDTO;
import com.example.backend.entity.Documento;
import com.example.backend.entity.TipoDocumento;
import com.example.backend.service.DocumentoService;
import com.example.backend.service.SeguridadService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/documentos")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class DocumentoController {

    private final DocumentoService documentoService;
    private final SeguridadService seguridadService;

    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<DocumentoResponseDTO> subirDocumento(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "apadrinadoId", required = false) Long apadrinadoId,
            @RequestParam(value = "expedienteId", required = false) Long expedienteId,
            @RequestParam(value = "actividadId", required = false) Long actividadId,
            @RequestParam(value = "tipoDocumento", required = false) TipoDocumento tipoDocumento,
            @RequestParam(value = "descripcion", required = false) String descripcion,
            @RequestParam(value = "usuarioId", required = false) Long usuarioId) {

        // FASE B: el apadrinado solo sube a su propio expediente/actividad;
        // el coordinador solo a expedientes bajo su responsabilidad
        seguridadService.usuarioActual();
        if (apadrinadoId != null) {
            seguridadService.verificarApadrinadoAccesible(apadrinadoId);
        }
        if (expedienteId != null) {
            seguridadService.verificarExpedienteAccesible(expedienteId);
        }
        if (actividadId != null) {
            seguridadService.verificarActividadAccesible(actividadId);
        }
        // FASE B: si se referencia un usuario, validar que sea el propio
        // o un apadrinado bajo responsabilidad (evita inferencia no autorizada)
        if (usuarioId != null) {
            seguridadService.verificarUsuarioAccesible(usuarioId);
        }

        DocumentoResponseDTO response = documentoService.subirDocumento(
                file, apadrinadoId, expedienteId, actividadId, tipoDocumento, descripcion, usuarioId);

        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @GetMapping("/{id}")
    public ResponseEntity<DocumentoResponseDTO> obtenerPorId(@PathVariable Long id) {
        seguridadService.verificarDocumentoAccesible(id);
        return ResponseEntity.ok(documentoService.obtenerPorId(id));
    }

    @GetMapping("/{id}/descargar")
    public ResponseEntity<Resource> descargarArchivo(@PathVariable Long id) {
        seguridadService.verificarDocumentoAccesible(id);
        Documento documento = documentoService.obtenerEntidad(id);
        Resource resource = documentoService.cargarArchivoComoRecurso(id);

        String contentType = documento.getTipoMime();
        if (contentType == null || contentType.isBlank() || contentType.equalsIgnoreCase("application/octet-stream")) {
            contentType = org.springframework.http.MediaTypeFactory.getMediaType(documento.getNombreOriginal())
                    .map(MediaType::toString)
                    .orElse("application/octet-stream");
        }

        org.springframework.http.ContentDisposition contentDisposition = org.springframework.http.ContentDisposition.attachment()
                .filename(documento.getNombreOriginal(), java.nio.charset.StandardCharsets.UTF_8)
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
        seguridadService.verificarDocumentoAccesible(id);
        Documento documento = documentoService.obtenerEntidad(id);
        Resource resource = documentoService.cargarArchivoComoRecurso(id);

        String contentType = documento.getTipoMime();
        if (contentType == null || contentType.isBlank() || contentType.equalsIgnoreCase("application/octet-stream")) {
            contentType = org.springframework.http.MediaTypeFactory.getMediaType(documento.getNombreOriginal())
                    .map(MediaType::toString)
                    .orElse("application/octet-stream");
        }

        org.springframework.http.ContentDisposition contentDisposition = org.springframework.http.ContentDisposition.inline()
                .filename(documento.getNombreOriginal(), java.nio.charset.StandardCharsets.UTF_8)
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

    @GetMapping("/apadrinado/{apadrinadoId}")
    public ResponseEntity<List<DocumentoResponseDTO>> listarPorApadrinado(
            @PathVariable Long apadrinadoId,
            @RequestParam(value = "tipo", required = false) TipoDocumento tipo) {
        seguridadService.verificarApadrinadoAccesible(apadrinadoId);
        return ResponseEntity.ok(documentoService.listarPorApadrinado(apadrinadoId, tipo));
    }

    @GetMapping("/expediente/{expedienteId}")
    public ResponseEntity<List<DocumentoResponseDTO>> listarPorExpediente(
            @PathVariable Long expedienteId,
            @RequestParam(value = "tipo", required = false) TipoDocumento tipo) {
        seguridadService.verificarExpedienteAccesible(expedienteId);
        return ResponseEntity.ok(documentoService.listarPorExpediente(expedienteId, tipo));
    }

    @GetMapping("/actividad/{actividadId}")
    public ResponseEntity<List<DocumentoResponseDTO>> listarPorActividad(@PathVariable Long actividadId) {
        seguridadService.verificarActividadAccesible(actividadId);
        return ResponseEntity.ok(documentoService.listarPorActividad(actividadId));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        seguridadService.verificarDocumentoAccesible(id);
        documentoService.eliminar(id);
        return ResponseEntity.noContent().build();
    }
}
