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

import com.example.backend.dto.UsuarioRequestDTO;
import com.example.backend.dto.UsuarioResponseDTO;
import com.example.backend.service.SeguridadService;
import com.example.backend.service.UsuarioService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/usuarios")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class UsuarioController {

    private final UsuarioService usuarioService;
    private final SeguridadService seguridadService;

    @GetMapping
    public ResponseEntity<List<UsuarioResponseDTO>> listarTodos() {
        // FASE B: la lista global de usuarios es información interna
        throw new com.example.backend.config.AccesoDenegadoException(
                "Acceso denegado: lista de usuarios restringida.");
    }

    @GetMapping("/{id}")
    public ResponseEntity<UsuarioResponseDTO> obtenerPorId(@PathVariable Long id) {
        // FASE B: cada usuario solo consulta su propio perfil
        if (!seguridadService.usuarioActual().getId().equals(id)) {
            throw new com.example.backend.config.AccesoDenegadoException(
                    "No puede consultar el perfil de otro usuario.");
        }
        return ResponseEntity.ok(usuarioService.obtenerPorId(id));
    }

    @PostMapping
    public ResponseEntity<UsuarioResponseDTO> crear(@RequestBody UsuarioRequestDTO request) {
        // FASE B: la creación de usuarios es una función administrativa;
        // el registro público es /api/auth/register
        throw new com.example.backend.config.AccesoDenegadoException(
                "La creación de usuarios es una función administrativa.");
    }

    /** Perfil del usuario autenticado. */
    @GetMapping("/me")
    public ResponseEntity<UsuarioResponseDTO> miPerfil() {
        return ResponseEntity.ok(usuarioService.obtenerPorId(seguridadService.usuarioActual().getId()));
    }

    /** Actualiza la información permitida del perfil propio. */
    @PutMapping("/me")
    public ResponseEntity<UsuarioResponseDTO> actualizarMiPerfil(
            @RequestBody com.example.backend.dto.PerfilRequestDTO request) {
        return ResponseEntity.ok(usuarioService.actualizarPerfil(seguridadService.usuarioActual().getId(), request));
    }

    @PutMapping("/{id}")
    public ResponseEntity<UsuarioResponseDTO> actualizar(
            @PathVariable Long id,
            @RequestBody com.example.backend.dto.PerfilRequestDTO request) {
        // Solo el propio usuario; correo, contraseña y rol se gestionan por otros medios
        if (!seguridadService.usuarioActual().getId().equals(id)) {
            throw new com.example.backend.config.AccesoDenegadoException(
                    "No puede modificar el perfil de otro usuario.");
        }
        return ResponseEntity.ok(usuarioService.actualizarPerfil(id, request));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        throw new com.example.backend.config.AccesoDenegadoException(
                "La eliminación de usuarios es una función administrativa.");
    }
}
