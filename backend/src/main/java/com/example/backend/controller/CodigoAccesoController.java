package com.example.backend.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.backend.dto.CodigoAccesoRequestDTO;
import com.example.backend.dto.CodigoAccesoResponseDTO;
import com.example.backend.service.CodigoAccesoService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Gestión de códigos de acceso a comunidades.
 * Función exclusiva del coordinador responsable de la comunidad.
 */
@RestController
@RequestMapping("/api/codigos-acceso")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class CodigoAccesoController {

    private final CodigoAccesoService codigoAccesoService;

    @PostMapping("/comunidad/{comunidadId}")
    public ResponseEntity<CodigoAccesoResponseDTO> generar(
            @PathVariable Long comunidadId,
            @Valid @RequestBody CodigoAccesoRequestDTO request) {
        CodigoAccesoResponseDTO generado = codigoAccesoService.generar(comunidadId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(generado);
    }

    @GetMapping("/comunidad/{comunidadId}")
    public ResponseEntity<List<CodigoAccesoResponseDTO>> listarPorComunidad(@PathVariable Long comunidadId) {
        return ResponseEntity.ok(codigoAccesoService.listarPorComunidad(comunidadId));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> desactivar(@PathVariable Long id) {
        codigoAccesoService.desactivar(id);
        return ResponseEntity.noContent().build();
    }
}
