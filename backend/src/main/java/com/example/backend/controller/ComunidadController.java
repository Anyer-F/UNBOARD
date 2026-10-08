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
import com.example.backend.entity.Coordinador;
import com.example.backend.service.ComunidadService;
import com.example.backend.service.SeguridadService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/comunidades")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class ComunidadController {

    private final ComunidadService comunidadService;
    private final SeguridadService seguridadService;

    @GetMapping
    public ResponseEntity<List<ComunidadResponseDTO>> listarTodas() {
        // FASE B: lectura permitida a usuarios autenticados (la app la usa
        // para mostrar nombres de comunidades). La escritura está protegida abajo.
        seguridadService.usuarioActual();
        return ResponseEntity.ok(comunidadService.listarTodas());
    }

    @GetMapping("/{id}")
    public ResponseEntity<ComunidadResponseDTO> obtenerPorId(@PathVariable Long id) {
        seguridadService.usuarioActual();
        return ResponseEntity.ok(comunidadService.obtenerPorId(id));
    }

    @PostMapping
    public ResponseEntity<ComunidadResponseDTO> crear(@RequestBody ComunidadRequestDTO request) {
        // FASE B: solo coordinadores pueden crear comunidades bajo su responsabilidad
        seguridadService.requerirCoordinador();
        ComunidadResponseDTO nueva = comunidadService.crear(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(nueva);
    }

    @PutMapping("/{id}")
    public ResponseEntity<ComunidadResponseDTO> actualizar(
            @PathVariable Long id,
            @RequestBody ComunidadRequestDTO request) {
        // FASE B: solo el coordinador puede actualizar su propia comunidad
        seguridadService.requerirCoordinador();
        seguridadService.verificarComunidadPropia(id);
        return ResponseEntity.ok(comunidadService.actualizar(id, request));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        // FASE B: solo el coordinador puede eliminar su propia comunidad
        seguridadService.requerirCoordinador();
        seguridadService.verificarComunidadPropia(id);
        comunidadService.eliminar(id);
        return ResponseEntity.noContent().build();
    }
}
