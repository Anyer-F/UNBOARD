package com.example.backend.controller;

import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.example.backend.dto.ActividadDetalleDTO;
import com.example.backend.dto.ActividadRequestDTO;
import com.example.backend.dto.ActividadResponseDTO;
import com.example.backend.dto.DocumentoResponseDTO;
import com.example.backend.dto.ExportacionResponseDTO;
import com.example.backend.dto.HistorialActividadResponseDTO;
import com.example.backend.dto.IdsRequestDTO;
import com.example.backend.entity.TipoActividad;
import com.example.backend.service.ActividadService;
import com.example.backend.service.ExportacionService;
import com.example.backend.service.HistorialActividadService;
import com.example.backend.service.ModuloService;
import com.example.backend.service.SeguridadService;

import lombok.RequiredArgsConstructor;

/**
 * Actividades (funciones del coordinador): tablero, CRUD, contenido
 * adjunto, cambio de módulo, historial y exportación PDF / ZIP.
 */
@RestController
@RequestMapping("/api/actividades")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class ActividadController {

    private final ActividadService actividadService;
    private final ModuloService moduloService;
    private final ExportacionService exportacionService;
    private final HistorialActividadService historialService;
    private final SeguridadService seguridadService;

    /** Tablero de actividades, filtrable por comunidad, módulo y tipo. */
    @GetMapping
    public ResponseEntity<List<ActividadResponseDTO>> tablero(
            @RequestParam(required = false) Long comunidadId,
            @RequestParam(required = false) Long moduloId,
            @RequestParam(required = false) TipoActividad tipo) {
        return ResponseEntity.ok(actividadService.tablero(comunidadId, moduloId, tipo));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ActividadDetalleDTO> detalle(@PathVariable Long id) {
        return ResponseEntity.ok(actividadService.detalle(id));
    }

    @PostMapping
    public ResponseEntity<ActividadResponseDTO> crear(@RequestBody ActividadRequestDTO request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(actividadService.crear(request));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ActividadResponseDTO> actualizar(
            @PathVariable Long id, @RequestBody ActividadRequestDTO request) {
        return ResponseEntity.ok(actividadService.actualizar(id, request));
    }

    /**
     * Elimina la actividad. Si tiene entregas responde 409 hasta que se
     * confirme (confirmar=true) y la eliminación es lógica.
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, String>> eliminar(
            @PathVariable Long id,
            @RequestParam(defaultValue = "false") boolean confirmar) {
        return ResponseEntity.ok(Map.of("eliminacion", actividadService.eliminar(id, confirmar)));
    }

    @PostMapping(value = "/{id}/adjuntos", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<DocumentoResponseDTO> subirAdjunto(
            @PathVariable Long id,
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "descripcion", required = false) String descripcion) {
        return ResponseEntity.status(HttpStatus.CREATED).body(actividadService.subirAdjunto(id, file, descripcion));
    }

    @DeleteMapping("/{id}/adjuntos/{documentoId}")
    public ResponseEntity<Void> eliminarAdjunto(@PathVariable Long id, @PathVariable Long documentoId) {
        actividadService.eliminarAdjunto(id, documentoId);
        return ResponseEntity.noContent().build();
    }

    /** Mueve la actividad a otro módulo de su comunidad. */
    @PatchMapping("/{id}/modulo")
    public ResponseEntity<ActividadDetalleDTO> mover(@PathVariable Long id, @RequestBody IdsRequestDTO request) {
        moduloService.moverActividad(id, request.getModuloId());
        return ResponseEntity.ok(actividadService.detalle(id));
    }

    @GetMapping("/{id}/historial")
    public ResponseEntity<List<HistorialActividadResponseDTO>> historial(@PathVariable Long id) {
        seguridadService.verificarActividadPropia(id);
        return ResponseEntity.ok(historialService.listarPorActividad(id));
    }

    /** Expediente PDF de la actividad con las entregas aprobadas. */
    @PostMapping("/{id}/exportar-pdf")
    public ResponseEntity<ExportacionResponseDTO> exportarPdf(@PathVariable Long id) {
        return ResponseEntity.status(HttpStatus.CREATED).body(exportacionService.pdfActividad(id));
    }

    /** Carpeta ZIP de la actividad con los archivos de las entregas aprobadas. */
    @PostMapping("/{id}/exportar-zip")
    public ResponseEntity<ExportacionResponseDTO> exportarZip(@PathVariable Long id) {
        return ResponseEntity.status(HttpStatus.CREATED).body(exportacionService.zipActividad(id));
    }
}
