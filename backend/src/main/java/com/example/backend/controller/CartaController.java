package com.example.backend.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.backend.dto.CartaResponseDTO;
import com.example.backend.service.CartaService;

import lombok.RequiredArgsConstructor;

/**
 * Consulta de cartas. Para escribirlas, ver las entregas en
 * {@link AsignacionController}.
 */
@RestController
@RequestMapping("/api/cartas")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class CartaController {

    private final CartaService cartaService;

    @GetMapping("/{id}")
    public ResponseEntity<CartaResponseDTO> obtenerPorId(@PathVariable Long id) {
        return ResponseEntity.ok(cartaService.obtenerPorId(id));
    }

    @GetMapping("/apadrinado/{apadrinadoId}")
    public ResponseEntity<List<CartaResponseDTO>> listarPorApadrinado(@PathVariable Long apadrinadoId) {
        return ResponseEntity.ok(cartaService.listarPorApadrinado(apadrinadoId));
    }
}
