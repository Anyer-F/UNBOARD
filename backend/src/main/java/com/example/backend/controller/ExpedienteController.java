package com.example.backend.controller;

import java.nio.charset.StandardCharsets;
import java.util.List;

import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.backend.dto.ExpedienteResponseDTO;
import com.example.backend.service.ExpedienteExportService;
import com.example.backend.service.ExpedienteService;
import com.example.backend.service.SeguridadService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/expedientes")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class ExpedienteController {

    private final ExpedienteService expedienteService;
    private final ExpedienteExportService expedienteExportService;
    private final SeguridadService seguridadService;

    @GetMapping
    public ResponseEntity<List<ExpedienteResponseDTO>> listarTodos() {
        // FASE B: el coordinador ve los expedientes de sus apadrinados; el apadrinado el suyo
        var coordinador = seguridadService.coordinadorActual();
        if (coordinador != null) {
            return ResponseEntity.ok(expedienteService.listarPorCoordinador(coordinador.getId()));
        }
        var apadrinado = seguridadService.apadrinadoActual();
        if (apadrinado != null) {
            return ResponseEntity.ok(
                    List.of(expedienteService.obtenerPorApadrinadoId(apadrinado.getId())));
        }
        throw new com.example.backend.config.AccesoDenegadoException("Acceso denegado.");
    }

    @GetMapping("/{id}")
    public ResponseEntity<ExpedienteResponseDTO> obtenerPorId(@PathVariable Long id) {
        seguridadService.verificarExpedienteAccesible(id);
        return ResponseEntity.ok(expedienteService.obtenerPorId(id));
    }

    @GetMapping("/apadrinado/{apadrinadoId}")
    public ResponseEntity<ExpedienteResponseDTO> obtenerPorApadrinadoId(@PathVariable Long apadrinadoId) {
        seguridadService.verificarApadrinadoAccesible(apadrinadoId);
        return ResponseEntity.ok(expedienteService.obtenerPorApadrinadoId(apadrinadoId));
    }

    @PostMapping("/apadrinado/{apadrinadoId}")
    public ResponseEntity<ExpedienteResponseDTO> crearParaApadrinado(@PathVariable Long apadrinadoId) {
        seguridadService.requerirCoordinador();
        seguridadService.verificarApadrinadoAccesible(apadrinadoId);
        ExpedienteResponseDTO creado = expedienteService.crearParaApadrinado(apadrinadoId);
        return ResponseEntity.status(HttpStatus.CREATED).body(creado);
    }

    // ==================== EXPORTACIÓN EN PDF ====================

    @GetMapping("/{id}/exportar-pdf")
    public ResponseEntity<Resource> exportarPdf(@PathVariable Long id) {
        seguridadService.verificarExpedienteAccesible(id);
        byte[] pdfBytes = expedienteExportService.generarPdfConsolidado(id);
        ByteArrayResource resource = new ByteArrayResource(pdfBytes);

        String filename = "Expediente_Digital_" + id + ".pdf";
        ContentDisposition disposition = ContentDisposition.attachment()
                .filename(filename, StandardCharsets.UTF_8)
                .build();

        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, disposition.toString())
                .contentLength(pdfBytes.length)
                .header(HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS, HttpHeaders.CONTENT_DISPOSITION)
                .body(resource);
    }

    @GetMapping("/{id}/ver-pdf")
    public ResponseEntity<Resource> verPdf(@PathVariable Long id) {
        seguridadService.verificarExpedienteAccesible(id);
        byte[] pdfBytes = expedienteExportService.generarPdfConsolidado(id);
        ByteArrayResource resource = new ByteArrayResource(pdfBytes);

        String filename = "Expediente_Digital_" + id + ".pdf";
        ContentDisposition disposition = ContentDisposition.inline()
                .filename(filename, StandardCharsets.UTF_8)
                .build();

        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, disposition.toString())
                .header(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate")
                .contentLength(pdfBytes.length)
                .header(HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS, HttpHeaders.CONTENT_DISPOSITION)
                .body(resource);
    }

    @GetMapping("/apadrinado/{apadrinadoId}/exportar-pdf")
    public ResponseEntity<Resource> exportarPdfPorApadrinado(@PathVariable Long apadrinadoId) {
        seguridadService.verificarApadrinadoAccesible(apadrinadoId);
        ExpedienteResponseDTO exp = expedienteService.obtenerPorApadrinadoId(apadrinadoId);
        return exportarPdf(exp.getId());
    }

    @GetMapping("/apadrinado/{apadrinadoId}/ver-pdf")
    public ResponseEntity<Resource> verPdfPorApadrinado(@PathVariable Long apadrinadoId) {
        seguridadService.verificarApadrinadoAccesible(apadrinadoId);
        ExpedienteResponseDTO exp = expedienteService.obtenerPorApadrinadoId(apadrinadoId);
        return verPdf(exp.getId());
    }

    // ==================== EXPORTACIÓN EN ZIP ====================

    @GetMapping("/{id}/exportar-zip")
    public ResponseEntity<Resource> exportarZip(@PathVariable Long id) {
        seguridadService.verificarExpedienteAccesible(id);
        byte[] zipBytes = expedienteExportService.generarZipOrganizado(id);
        ByteArrayResource resource = new ByteArrayResource(zipBytes);

        String filename = "Expediente_Organizado_" + id + ".zip";
        ContentDisposition disposition = ContentDisposition.attachment()
                .filename(filename, StandardCharsets.UTF_8)
                .build();

        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("application/zip"))
                .header(HttpHeaders.CONTENT_DISPOSITION, disposition.toString())
                .contentLength(zipBytes.length)
                .header(HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS, HttpHeaders.CONTENT_DISPOSITION)
                .body(resource);
    }

    @GetMapping("/apadrinado/{apadrinadoId}/exportar-zip")
    public ResponseEntity<Resource> exportarZipPorApadrinado(@PathVariable Long apadrinadoId) {
        seguridadService.verificarApadrinadoAccesible(apadrinadoId);
        ExpedienteResponseDTO exp = expedienteService.obtenerPorApadrinadoId(apadrinadoId);
        return exportarZip(exp.getId());
    }
}
