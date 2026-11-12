package com.example.backend.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.backend.dto.ComunidadRequestDTO;
import com.example.backend.dto.ComunidadResponseDTO;
import com.example.backend.dto.HistorialActividadResponseDTO;
import com.example.backend.dto.IdsRequestDTO;
import com.example.backend.dto.MiComunidadDTO;
import com.example.backend.dto.ModuloRequestDTO;
import com.example.backend.dto.ModuloResponseDTO;
import com.example.backend.service.ActividadService;
import com.example.backend.service.ComunidadService;
import com.example.backend.service.HistorialActividadService;
import com.example.backend.service.ModuloService;
import com.example.backend.service.SeguridadService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/comunidades")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class ComunidadController {

    private final ComunidadService comunidadService;
    private final ModuloService moduloService;
    private final ActividadService actividadService;
    private final HistorialActividadService historialService;
    private final SeguridadService seguridadService;

    /** Comunidades del usuario (las que administra o a la que pertenece). */
    @GetMapping
    public ResponseEntity<List<ComunidadResponseDTO>> listar() {
        return ResponseEntity.ok(comunidadService.listarMias());
    }

    /** Apadrinado: su comunidad, su coordinador y los módulos con sus actividades. */
    @GetMapping("/mia")
    public ResponseEntity<MiComunidadDTO> miComunidad() {
        return ResponseEntity.ok(actividadService.miComunidad());
    }

    @GetMapping("/{id}")
    public ResponseEntity<ComunidadResponseDTO> obtenerPorId(@PathVariable Long id) {
        return ResponseEntity.ok(comunidadService.obtenerPorId(id));
    }

    @PostMapping
    public ResponseEntity<ComunidadResponseDTO> crear(@RequestBody ComunidadRequestDTO request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(comunidadService.crear(request));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ComunidadResponseDTO> actualizar(
            @PathVariable Long id, @RequestBody ComunidadRequestDTO request) {
        return ResponseEntity.ok(comunidadService.actualizar(id, request));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        comunidadService.eliminar(id);
        return ResponseEntity.noContent().build();
    }

    // ==================== MÓDULOS ====================

    @GetMapping("/{id}/modulos")
    public ResponseEntity<List<ModuloResponseDTO>> modulos(@PathVariable Long id) {
        return ResponseEntity.ok(moduloService.listar(id));
    }

    @PostMapping("/{id}/modulos")
    public ResponseEntity<ModuloResponseDTO> crearModulo(
            @PathVariable Long id, @RequestBody ModuloRequestDTO request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(moduloService.crear(id, request));
    }

    /** Nuevo orden de los módulos (lista completa de IDs). */
    @PutMapping("/{id}/modulos/orden")
    public ResponseEntity<List<ModuloResponseDTO>> reordenar(
            @PathVariable Long id, @RequestBody IdsRequestDTO request) {
        return ResponseEntity.ok(moduloService.reordenar(id, request.getIds()));
    }

    // ==================== HISTORIAL ====================

    @GetMapping("/{id}/historial")
    public ResponseEntity<List<HistorialActividadResponseDTO>> historial(@PathVariable Long id) {
        seguridadService.verificarComunidadPropia(id);
        return ResponseEntity.ok(historialService.listarPorComunidades(List.of(id)));
    }
}
