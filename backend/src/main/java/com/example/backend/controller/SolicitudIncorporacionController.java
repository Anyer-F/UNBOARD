package com.example.backend.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.backend.dto.SolicitudIncorporacionRequestDTO;
import com.example.backend.dto.SolicitudIncorporacionResponseDTO;
import com.example.backend.service.SolicitudIncorporacionService;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Solicitudes de incorporación a comunidades.
 * - El apadrinado (sin comunidad) solicita con un código de acceso.
 * - El coordinador responsable aprueba o rechaza.
 */
@RestController
@RequestMapping("/api/solicitudes-incorporacion")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class SolicitudIncorporacionController {

    private final SolicitudIncorporacionService solicitudService;

    @PostMapping
    public ResponseEntity<SolicitudIncorporacionResponseDTO> solicitar(
            @Valid @RequestBody SolicitudIncorporacionRequestDTO request) {
        SolicitudIncorporacionResponseDTO creada = solicitudService.solicitar(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(creada);
    }

    @GetMapping("/mias")
    public ResponseEntity<List<SolicitudIncorporacionResponseDTO>> listarMias() {
        return ResponseEntity.ok(solicitudService.listarMias());
    }

    @GetMapping("/pendientes")
    public ResponseEntity<List<SolicitudIncorporacionResponseDTO>> listarPendientes() {
        return ResponseEntity.ok(solicitudService.listarPendientes());
    }

    @PatchMapping("/{id}/aprobar")
    public ResponseEntity<SolicitudIncorporacionResponseDTO> aprobar(@PathVariable Long id) {
        return ResponseEntity.ok(solicitudService.aprobar(id));
    }

    @PatchMapping("/{id}/rechazar")
    public ResponseEntity<SolicitudIncorporacionResponseDTO> rechazar(
            @PathVariable Long id,
            @RequestParam(value = "observaciones", required = false) String observaciones) {
        return ResponseEntity.ok(solicitudService.rechazar(id, observaciones));
    }
}
