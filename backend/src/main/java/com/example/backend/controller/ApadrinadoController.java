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

import com.example.backend.dto.ApadrinadoRequestDTO;
import com.example.backend.dto.ApadrinadoResponseDTO;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Coordinador;
import com.example.backend.service.ApadrinadoService;
import com.example.backend.service.SeguridadService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/apadrinados")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class ApadrinadoController {

    private final ApadrinadoService apadrinadoService;
    private final SeguridadService seguridadService;

    @GetMapping
    public ResponseEntity<List<ApadrinadoResponseDTO>> listarTodos() {
        // FASE B/F: el coordinador ve los apadrinados de TODAS sus
        // comunidades; el apadrinado solo su propio registro
        Coordinador coordinador = seguridadService.coordinadorActual();
        if (coordinador != null) {
            return ResponseEntity.ok(
                    apadrinadoService.listarAccesiblesPorCoordinador(coordinador));
        }
        Apadrinado apadrinado = seguridadService.apadrinadoActual();
        if (apadrinado != null) {
            return ResponseEntity.ok(List.of(apadrinadoService.obtenerPorId(apadrinado.getId())));
        }
        throw new com.example.backend.config.AccesoDenegadoException("Acceso denegado.");
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApadrinadoResponseDTO> obtenerPorId(@PathVariable Long id) {
        seguridadService.verificarApadrinadoAccesible(id);
        return ResponseEntity.ok(apadrinadoService.obtenerPorId(id));
    }

    @GetMapping("/usuario/{usuarioId}")
    public ResponseEntity<ApadrinadoResponseDTO> obtenerPorUsuarioId(@PathVariable Long usuarioId) {
        // FASE B: cada usuario solo consulta su propio perfil
        if (!seguridadService.usuarioActual().getId().equals(usuarioId)) {
            throw new com.example.backend.config.AccesoDenegadoException(
                    "No puede consultar el perfil de otro usuario.");
        }
        return ResponseEntity.ok(apadrinadoService.obtenerPorUsuarioId(usuarioId));
    }

    @GetMapping("/coordinador/{coordinadorId}")
    public ResponseEntity<List<ApadrinadoResponseDTO>> listarPorCoordinador(@PathVariable Long coordinadorId) {
        seguridadService.verificarCoordinadorPropio(coordinadorId);
        // FASE F: apadrinados de todas las comunidades del coordinador
        Coordinador coordinador = seguridadService.coordinadorActual();
        return ResponseEntity.ok(
                apadrinadoService.listarAccesiblesPorCoordinador(coordinador));
    }

    @GetMapping("/comunidad/{comunidadId}")
    public ResponseEntity<List<ApadrinadoResponseDTO>> listarPorComunidad(@PathVariable Long comunidadId) {
        seguridadService.verificarComunidadPropia(comunidadId);
        return ResponseEntity.ok(apadrinadoService.listarPorComunidad(comunidadId));
    }

    @PostMapping
    public ResponseEntity<ApadrinadoResponseDTO> crear(@RequestBody ApadrinadoRequestDTO request) {
        // FASE B: solo coordinadores; el apadrinado queda bajo su responsabilidad
        seguridadService.requerirCoordinador();
        Coordinador coordinador = seguridadService.coordinadorActual();
        request.setCoordinadorId(coordinador.getId());
        if (request.getComunidadId() != null) {
            // FASE F: el apadrinado puede crearse en cualquiera
            // de sus comunidades bajo responsabilidad
            seguridadService.verificarComunidadPropia(request.getComunidadId());
        } else if (coordinador.getComunidad() != null) {
            request.setComunidadId(coordinador.getComunidad().getId());
        }

        ApadrinadoResponseDTO nuevo = apadrinadoService.crear(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(nuevo);
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApadrinadoResponseDTO> actualizar(
            @PathVariable Long id,
            @RequestBody ApadrinadoRequestDTO request) {
        seguridadService.requerirCoordinador();
        seguridadService.verificarApadrinadoAccesible(id);
        // FASE B: no se permite reasignar a otro coordinador libremente
        Coordinador coordinador = seguridadService.coordinadorActual();
        request.setCoordinadorId(coordinador.getId());
        if (request.getComunidadId() != null) {
            // FASE F: solo puede moverlo a otra de sus comunidades
            seguridadService.verificarComunidadPropia(request.getComunidadId());
        } else if (coordinador.getComunidad() != null) {
            request.setComunidadId(coordinador.getComunidad().getId());
        }
        return ResponseEntity.ok(apadrinadoService.actualizar(id, request));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        seguridadService.requerirCoordinador();
        seguridadService.verificarApadrinadoAccesible(id);
        apadrinadoService.eliminar(id);
        return ResponseEntity.noContent().build();
    }
}
