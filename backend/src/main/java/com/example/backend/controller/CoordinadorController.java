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

import com.example.backend.dto.CoordinadorRequestDTO;
import com.example.backend.dto.CoordinadorResponseDTO;
import com.example.backend.dto.ComunidadResponseDTO;
import com.example.backend.entity.Coordinador;
import com.example.backend.service.CoordinadorService;
import com.example.backend.service.SeguridadService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/coordinadores")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class CoordinadorController {

    private final CoordinadorService coordinadorService;
    private final SeguridadService seguridadService;

    @GetMapping
    public ResponseEntity<List<CoordinadorResponseDTO>> listarTodos() {
        // FASE B: la lista global de coordinadores es información interna
        throw new com.example.backend.config.AccesoDenegadoException(
                "Acceso denegado: lista de coordinadores restringida.");
    }

    @GetMapping("/{id}")
    public ResponseEntity<CoordinadorResponseDTO> obtenerPorId(@PathVariable Long id) {
        // FASE B: cada coordinador solo consulta su propio perfil
        Coordinador coordinador = seguridadService.coordinadorActual();
        if (coordinador == null || !coordinador.getId().equals(id)) {
            throw new com.example.backend.config.AccesoDenegadoException(
                    "No puede consultar el perfil de otro coordinador.");
        }
        return ResponseEntity.ok(coordinadorService.obtenerPorId(id));
    }

    @GetMapping("/usuario/{usuarioId}")
    public ResponseEntity<CoordinadorResponseDTO> obtenerPorUsuarioId(@PathVariable Long usuarioId) {
        // FASE B: solo el propio usuario
        if (!seguridadService.usuarioActual().getId().equals(usuarioId)) {
            throw new com.example.backend.config.AccesoDenegadoException(
                    "No puede consultar el perfil de otro usuario.");
        }
        return ResponseEntity.ok(coordinadorService.obtenerPorUsuarioId(usuarioId));
    }

    @GetMapping("/comunidad/{comunidadId}")
    public ResponseEntity<List<CoordinadorResponseDTO>> listarPorComunidad(@PathVariable Long comunidadId) {
        seguridadService.verificarComunidadPropia(comunidadId);
        return ResponseEntity.ok(coordinadorService.listarPorComunidad(comunidadId));
    }

    /**
     * FASE F: lista todas las comunidades bajo la responsabilidad
     * del coordinador autenticado (principal + asociadas).
     */
    @GetMapping("/comunidades")
    public ResponseEntity<List<ComunidadResponseDTO>> listarMisComunidades() {
        Coordinador coordinador = seguridadService.coordinadorActual();
        if (coordinador == null) {
            throw new com.example.backend.config.AccesoDenegadoException(
                    "Esta función es exclusiva del rol Coordinador.");
        }
        return ResponseEntity.ok(coordinadorService.listarComunidadesDelCoordinador(coordinador.getId()));
    }

    /**
     * FASE F: asocia una comunidad existente al coordinador autenticado,
     * ampliando las comunidades bajo su responsabilidad.
     * Una comunidad solo puede estar bajo la responsabilidad de un coordinador.
     */
    @PostMapping("/comunidades/{comunidadId}")
    public ResponseEntity<List<ComunidadResponseDTO>> asociarComunidad(@PathVariable Long comunidadId) {
        Coordinador coordinador = seguridadService.coordinadorActual();
        if (coordinador == null) {
            throw new com.example.backend.config.AccesoDenegadoException(
                    "Esta función es exclusiva del rol Coordinador.");
        }
        return ResponseEntity.ok(coordinadorService.asociarComunidad(coordinador.getId(), comunidadId));
    }

    /**
     * FASE F: desasocia una comunidad de las responsabilidades del
     * coordinador autenticado (la comunidad principal no se puede desasociar).
     */
    @DeleteMapping("/comunidades/{comunidadId}")
    public ResponseEntity<List<ComunidadResponseDTO>> desasociarComunidad(@PathVariable Long comunidadId) {
        Coordinador coordinador = seguridadService.coordinadorActual();
        if (coordinador == null) {
            throw new com.example.backend.config.AccesoDenegadoException(
                    "Esta función es exclusiva del rol Coordinador.");
        }
        return ResponseEntity.ok(coordinadorService.desasociarComunidad(coordinador.getId(), comunidadId));
    }

    @PostMapping
    public ResponseEntity<CoordinadorResponseDTO> crear(@RequestBody CoordinadorRequestDTO request) {
        // FASE B: la creación de coordinadores es una función administrativa
        throw new com.example.backend.config.AccesoDenegadoException(
                "La creación de coordinadores es una función administrativa.");
    }

    @PutMapping("/{id}")
    public ResponseEntity<CoordinadorResponseDTO> actualizar(
            @PathVariable Long id,
            @RequestBody CoordinadorRequestDTO request) {
        throw new com.example.backend.config.AccesoDenegadoException(
                "La modificación de coordinadores es una función administrativa.");
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        throw new com.example.backend.config.AccesoDenegadoException(
                "La eliminación de coordinadores es una función administrativa.");
    }
}
