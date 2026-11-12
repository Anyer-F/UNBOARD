package com.example.backend.controller;

import java.time.LocalDate;
import java.util.List;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.backend.dto.ExpedienteResponseDTO;
import com.example.backend.dto.ExportacionResponseDTO;
import com.example.backend.dto.HistorialActividadResponseDTO;
import com.example.backend.dto.ObservacionResponseDTO;
import com.example.backend.dto.TextoRequestDTO;
import com.example.backend.service.ExpedienteService;
import com.example.backend.service.ExportacionService;

import lombok.RequiredArgsConstructor;

/**
 * Expedientes digitales: función exclusiva del coordinador. El servicio
 * valida el rol y que el apadrinado pertenezca a sus comunidades.
 */
@RestController
@RequestMapping("/api/expedientes")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class ExpedienteController {

    private final ExpedienteService expedienteService;
    private final ExportacionService exportacionService;

    @GetMapping
    public ResponseEntity<List<ExpedienteResponseDTO>> listar() {
        return ResponseEntity.ok(expedienteService.listarMios());
    }

    @GetMapping("/{id}")
    public ResponseEntity<ExpedienteResponseDTO> obtenerPorId(@PathVariable Long id) {
        return ResponseEntity.ok(expedienteService.obtenerPorId(id));
    }

    @GetMapping("/apadrinado/{apadrinadoId}")
    public ResponseEntity<ExpedienteResponseDTO> obtenerPorApadrinado(@PathVariable Long apadrinadoId) {
        return ResponseEntity.ok(expedienteService.obtenerPorApadrinado(apadrinadoId));
    }

    @PostMapping("/apadrinado/{apadrinadoId}/observaciones")
    public ResponseEntity<ObservacionResponseDTO> agregarObservacion(
            @PathVariable Long apadrinadoId, @RequestBody TextoRequestDTO request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(
                expedienteService.agregarObservacion(apadrinadoId, request.getTexto(), request.getAsignacionId()));
    }

    @DeleteMapping("/observaciones/{observacionId}")
    public ResponseEntity<Void> eliminarObservacion(@PathVariable Long observacionId) {
        expedienteService.eliminarObservacion(observacionId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/apadrinado/{apadrinadoId}/historial")
    public ResponseEntity<List<HistorialActividadResponseDTO>> historial(@PathVariable Long apadrinadoId) {
        return ResponseEntity.ok(expedienteService.historial(apadrinadoId));
    }

    /** Expediente PDF del apadrinado por intervalo de tiempo (fecha de asignación). */
    @PostMapping("/apadrinado/{apadrinadoId}/exportar-pdf")
    public ResponseEntity<ExportacionResponseDTO> exportarPdf(
            @PathVariable Long apadrinadoId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate hasta) {
        return ResponseEntity.status(HttpStatus.CREATED).body(exportacionService.pdfApadrinado(apadrinadoId, desde, hasta));
    }

    /** Carpeta ZIP con los archivos de las entregas aprobadas del apadrinado en el intervalo. */
    @PostMapping("/apadrinado/{apadrinadoId}/exportar-zip")
    public ResponseEntity<ExportacionResponseDTO> exportarZip(
            @PathVariable Long apadrinadoId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate hasta) {
        return ResponseEntity.status(HttpStatus.CREATED).body(exportacionService.zipApadrinado(apadrinadoId, desde, hasta));
    }
}
