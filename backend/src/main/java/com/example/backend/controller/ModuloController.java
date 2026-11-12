package com.example.backend.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.backend.dto.ModuloRequestDTO;
import com.example.backend.dto.ModuloResponseDTO;
import com.example.backend.service.ModuloService;

import lombok.RequiredArgsConstructor;

/**
 * Edición de módulos. Listar, crear y reordenar están en
 * /api/comunidades/{id}/modulos.
 */
@RestController
@RequestMapping("/api/modulos")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class ModuloController {

    private final ModuloService moduloService;

    /** Renombra, cambia la descripción o la posición (orden) del módulo. */
    @PutMapping("/{id}")
    public ResponseEntity<ModuloResponseDTO> actualizar(@PathVariable Long id, @RequestBody ModuloRequestDTO request) {
        return ResponseEntity.ok(moduloService.actualizar(id, request));
    }

    /** Solo módulos sin actividades; la comunidad conserva al menos uno. */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        moduloService.eliminar(id);
        return ResponseEntity.noContent().build();
    }
}
