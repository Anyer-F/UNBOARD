package com.example.backend.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.backend.dto.HistorialActividadResponseDTO;
import com.example.backend.service.HistorialActividadService;
import com.example.backend.service.SeguridadService;

import lombok.RequiredArgsConstructor;

/**
 * Historial de cambios de las comunidades del coordinador.
 */
@RestController
@RequestMapping("/api/historial")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class HistorialController {

    private final HistorialActividadService historialService;
    private final SeguridadService seguridadService;

    @GetMapping
    public ResponseEntity<List<HistorialActividadResponseDTO>> listar() {
        seguridadService.requerirCoordinadorActual();
        return ResponseEntity.ok(historialService.listarPorComunidades(seguridadService.comunidadesDelCoordinador()));
    }
}
