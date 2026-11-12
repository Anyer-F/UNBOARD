package com.example.backend.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.example.backend.dto.AsignacionDetalleDTO;
import com.example.backend.dto.AsignacionResponseDTO;
import com.example.backend.dto.CartaRequestDTO;
import com.example.backend.dto.CartaResponseDTO;
import com.example.backend.dto.DocumentoResponseDTO;
import com.example.backend.dto.EntregaResponseDTO;
import com.example.backend.dto.HistorialActividadResponseDTO;
import com.example.backend.dto.TableroApadrinadoDTO;
import com.example.backend.dto.TextoRequestDTO;
import com.example.backend.entity.TipoDocumento;
import com.example.backend.service.ActividadService;
import com.example.backend.service.EntregaService;

import lombok.RequiredArgsConstructor;

/**
 * Actividades asignadas a cada apadrinado:
 * - Apadrinado: tablero de pendientes, preparar y enviar la entrega,
 *   marcar anuncios y material como vistos.
 * - Coordinador: revisar, aprobar o solicitar corrección.
 */
@RestController
@RequestMapping("/api/asignaciones")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class AsignacionController {

    private final ActividadService actividadService;
    private final EntregaService entregaService;

    // ==================== APADRINADO ====================

    @GetMapping("/mias")
    public ResponseEntity<List<AsignacionResponseDTO>> mias() {
        return ResponseEntity.ok(actividadService.misAsignaciones());
    }

    @GetMapping("/tablero")
    public ResponseEntity<TableroApadrinadoDTO> tablero() {
        return ResponseEntity.ok(actividadService.tableroApadrinado());
    }

    @GetMapping("/{id}")
    public ResponseEntity<AsignacionDetalleDTO> detalle(@PathVariable Long id) {
        return ResponseEntity.ok(entregaService.detalle(id));
    }

    @PostMapping("/{id}/visto")
    public ResponseEntity<AsignacionResponseDTO> visto(@PathVariable Long id) {
        return ResponseEntity.ok(actividadService.marcarVisto(id));
    }

    /** Comienza (o retoma) la entrega: pasa a En progreso. */
    @PostMapping("/{id}/entrega")
    public ResponseEntity<EntregaResponseDTO> iniciar(@PathVariable Long id) {
        return ResponseEntity.ok(entregaService.iniciar(id));
    }

    /** Documento, fotografía o evidencia (tipo = DOCUMENTO, FOTOGRAFIA o EVIDENCIA). */
    @PostMapping(value = "/{id}/entrega/archivos", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<DocumentoResponseDTO> subirArchivo(
            @PathVariable Long id,
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "tipo", required = false) TipoDocumento tipo,
            @RequestParam(value = "descripcion", required = false) String descripcion) {
        return ResponseEntity.status(HttpStatus.CREATED).body(entregaService.subirArchivo(id, file, tipo, descripcion));
    }

    @DeleteMapping("/{id}/entrega/archivos/{documentoId}")
    public ResponseEntity<Void> eliminarArchivo(@PathVariable Long id, @PathVariable Long documentoId) {
        entregaService.eliminarArchivo(id, documentoId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/entrega/cartas")
    public ResponseEntity<CartaResponseDTO> escribirCarta(@PathVariable Long id, @RequestBody CartaRequestDTO request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(entregaService.guardarCarta(id, null, request));
    }

    @PutMapping("/{id}/entrega/cartas/{cartaId}")
    public ResponseEntity<CartaResponseDTO> editarCarta(
            @PathVariable Long id, @PathVariable Long cartaId, @RequestBody CartaRequestDTO request) {
        return ResponseEntity.ok(entregaService.guardarCarta(id, cartaId, request));
    }

    @DeleteMapping("/{id}/entrega/cartas/{cartaId}")
    public ResponseEntity<Void> eliminarCarta(@PathVariable Long id, @PathVariable Long cartaId) {
        entregaService.eliminarCarta(id, cartaId);
        return ResponseEntity.noContent().build();
    }

    /** Envía la entrega para revisión, con el comentario del apadrinado. */
    @PostMapping("/{id}/entrega/enviar")
    public ResponseEntity<EntregaResponseDTO> enviar(
            @PathVariable Long id, @RequestBody(required = false) TextoRequestDTO request) {
        return ResponseEntity.ok(entregaService.enviar(id, request != null ? request.getTexto() : null));
    }

    // ==================== COORDINADOR ====================

    @PostMapping("/{id}/revision/iniciar")
    public ResponseEntity<EntregaResponseDTO> iniciarRevision(@PathVariable Long id) {
        return ResponseEntity.ok(entregaService.iniciarRevision(id));
    }

    @PostMapping("/{id}/revision/aprobar")
    public ResponseEntity<EntregaResponseDTO> aprobar(
            @PathVariable Long id, @RequestBody(required = false) TextoRequestDTO request) {
        return ResponseEntity.ok(entregaService.aprobar(id, request != null ? request.getTexto() : null));
    }

    /** Solicita una corrección; texto = sugerencias de mejora (obligatorio). */
    @PostMapping("/{id}/revision/correccion")
    public ResponseEntity<EntregaResponseDTO> correccion(
            @PathVariable Long id, @RequestBody TextoRequestDTO request) {
        return ResponseEntity.ok(entregaService.solicitarCorreccion(id, request.getTexto()));
    }

    @GetMapping("/{id}/historial")
    public ResponseEntity<List<HistorialActividadResponseDTO>> historial(@PathVariable Long id) {
        return ResponseEntity.ok(entregaService.historial(id));
    }
}
