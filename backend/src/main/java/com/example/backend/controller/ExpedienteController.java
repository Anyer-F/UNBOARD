package com.example.backend.controller;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.List;

import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.format.annotation.DateTimeFormat;
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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.backend.dto.ActividadComunidadResumenDTO;
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

    private static final MediaType ZIP = MediaType.parseMediaType("application/zip");

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
    // Todas las exportaciones aceptan un intervalo opcional [desde, hasta]
    // (formato ISO yyyy-MM-dd) para generar el expediente de un período.

    @GetMapping("/{id}/exportar-pdf")
    public ResponseEntity<Resource> exportarPdf(
            @PathVariable Long id,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate hasta) {
        seguridadService.verificarExpedienteAccesible(id);
        byte[] pdfBytes = expedienteExportService.generarPdfConsolidado(id, desde, hasta);
        return responderArchivo(pdfBytes, "Expediente_Digital_" + id + ".pdf", MediaType.APPLICATION_PDF, false);
    }

    @GetMapping("/{id}/ver-pdf")
    public ResponseEntity<Resource> verPdf(
            @PathVariable Long id,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate hasta) {
        seguridadService.verificarExpedienteAccesible(id);
        byte[] pdfBytes = expedienteExportService.generarPdfConsolidado(id, desde, hasta);
        return responderArchivo(pdfBytes, "Expediente_Digital_" + id + ".pdf", MediaType.APPLICATION_PDF, true);
    }

    @GetMapping("/apadrinado/{apadrinadoId}/exportar-pdf")
    public ResponseEntity<Resource> exportarPdfPorApadrinado(
            @PathVariable Long apadrinadoId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate hasta) {
        seguridadService.verificarApadrinadoAccesible(apadrinadoId);
        ExpedienteResponseDTO exp = expedienteService.obtenerPorApadrinadoId(apadrinadoId);
        return exportarPdf(exp.getId(), desde, hasta);
    }

    @GetMapping("/apadrinado/{apadrinadoId}/ver-pdf")
    public ResponseEntity<Resource> verPdfPorApadrinado(
            @PathVariable Long apadrinadoId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate hasta) {
        seguridadService.verificarApadrinadoAccesible(apadrinadoId);
        ExpedienteResponseDTO exp = expedienteService.obtenerPorApadrinadoId(apadrinadoId);
        return verPdf(exp.getId(), desde, hasta);
    }

    // ==================== EXPORTACIÓN EN ZIP ====================

    @GetMapping("/{id}/exportar-zip")
    public ResponseEntity<Resource> exportarZip(
            @PathVariable Long id,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate hasta) {
        seguridadService.verificarExpedienteAccesible(id);
        byte[] zipBytes = expedienteExportService.generarZipOrganizado(id, desde, hasta);
        return responderArchivo(zipBytes, "Expediente_Organizado_" + id + ".zip", ZIP, false);
    }

    @GetMapping("/apadrinado/{apadrinadoId}/exportar-zip")
    public ResponseEntity<Resource> exportarZipPorApadrinado(
            @PathVariable Long apadrinadoId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate hasta) {
        seguridadService.verificarApadrinadoAccesible(apadrinadoId);
        ExpedienteResponseDTO exp = expedienteService.obtenerPorApadrinadoId(apadrinadoId);
        return exportarZip(exp.getId(), desde, hasta);
    }

    // ==================== EXPEDIENTE DE ACTIVIDAD ====================

    /**
     * Operaciones de actividad de una comunidad (creación masiva = una
     * fila de Actividad por apadrinado), para elegir de cuál generar
     * el expediente de actividad.
     */
    @GetMapping("/actividades/comunidad/{comunidadId}")
    public ResponseEntity<List<ActividadComunidadResumenDTO>> listarActividadesPorComunidad(
            @PathVariable Long comunidadId) {
        seguridadService.requerirCoordinador();
        seguridadService.verificarComunidadAccesible(comunidadId);
        return ResponseEntity.ok(expedienteExportService.listarActividadesPorComunidad(comunidadId));
    }

    /**
     * Expediente de actividad en PDF: consolida una misma operación con
     * los apadrinados de la comunidad, su estado, la última acción
     * registrada y las evidencias. Con {@code soloAprobadas=true} incluye
     * únicamente las entregas aprobadas.
     */
    @GetMapping("/actividad/{actividadId}/expediente-pdf")
    public ResponseEntity<Resource> expedienteActividadPdf(
            @PathVariable Long actividadId,
            @RequestParam(required = false) Long comunidadId,
            @RequestParam(defaultValue = "false") boolean soloAprobadas) {
        Long idComunidad = verificarActividadDeComunidad(actividadId, comunidadId);
        byte[] pdfBytes = expedienteExportService.generarPdfActividad(actividadId, idComunidad, soloAprobadas);
        return responderArchivo(pdfBytes, "Expediente_Actividad_" + actividadId + ".pdf",
                MediaType.APPLICATION_PDF, false);
    }

    /** Expediente de actividad en ZIP: PDF + evidencias por apadrinado. */
    @GetMapping("/actividad/{actividadId}/expediente-zip")
    public ResponseEntity<Resource> expedienteActividadZip(
            @PathVariable Long actividadId,
            @RequestParam(required = false) Long comunidadId,
            @RequestParam(defaultValue = "false") boolean soloAprobadas) {
        Long idComunidad = verificarActividadDeComunidad(actividadId, comunidadId);
        byte[] zipBytes = expedienteExportService.generarZipActividad(actividadId, idComunidad, soloAprobadas);
        return responderArchivo(zipBytes, "Expediente_Actividad_" + actividadId + ".zip", ZIP, false);
    }

    // ==================== UTILIDADES ====================

    private Long verificarActividadDeComunidad(Long actividadId, Long comunidadId) {
        seguridadService.requerirCoordinador();
        seguridadService.verificarActividadAccesible(actividadId);
        Long idComunidad = expedienteExportService.resolverComunidadActividad(actividadId, comunidadId);
        seguridadService.verificarComunidadAccesible(idComunidad);
        return idComunidad;
    }

    private ResponseEntity<Resource> responderArchivo(byte[] bytes, String filename, MediaType tipo, boolean inline) {
        ContentDisposition disposition = (inline ? ContentDisposition.inline() : ContentDisposition.attachment())
                .filename(filename, StandardCharsets.UTF_8)
                .build();

        return ResponseEntity.ok()
                .contentType(tipo)
                .header(HttpHeaders.CONTENT_DISPOSITION, disposition.toString())
                .header(HttpHeaders.CACHE_CONTROL, "no-cache, no-store, must-revalidate")
                .contentLength(bytes.length)
                .header(HttpHeaders.ACCESS_CONTROL_EXPOSE_HEADERS, HttpHeaders.CONTENT_DISPOSITION)
                .body(new ByteArrayResource(bytes));
    }
}
