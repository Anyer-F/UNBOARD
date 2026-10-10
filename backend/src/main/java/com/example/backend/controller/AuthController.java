package com.example.backend.controller;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.backend.dto.CambiarPasswordRequestDTO;
import com.example.backend.dto.LoginRequestDTO;
import com.example.backend.dto.LoginResponseDTO;
import com.example.backend.dto.RecuperarPasswordRequestDTO;
import com.example.backend.dto.RestablecerPasswordRequestDTO;
import com.example.backend.dto.UsuarioRequestDTO;
import com.example.backend.dto.VerificarCodigoRequestDTO;
import com.example.backend.service.AuthService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/login")
    public ResponseEntity<LoginResponseDTO> login(@RequestBody LoginRequestDTO request) {
        LoginResponseDTO response = authService.autenticar(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/register")
    public ResponseEntity<LoginResponseDTO> register(@RequestBody UsuarioRequestDTO request) {
        LoginResponseDTO response = authService.registrar(request);
        return ResponseEntity.status(org.springframework.http.HttpStatus.CREATED).body(response);
    }

    @GetMapping("/perfil")
    public ResponseEntity<LoginResponseDTO> obtenerPerfil(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            return ResponseEntity.status(401).build();
        }
        LoginResponseDTO response = authService.obtenerPerfil(authentication.getName());
        return ResponseEntity.ok(response);
    }

    // ==================== RECUPERACIÓN DE CONTRASEÑA ====================

    /**
     * Paso 1: solicita un código de recuperación para el correo.
     * El código se registra en el log del servidor (prototipo).
     * En producción se enviará por correo electrónico y NUNCA se
     * devolverá en la respuesta HTTP.
     */
    @PostMapping("/recuperar-password")
    public ResponseEntity<Map<String, Object>> recuperarPassword(
            @RequestBody RecuperarPasswordRequestDTO request) {
        authService.solicitarRecuperacion(request.getCorreo());
        return ResponseEntity.ok(Map.of(
                "mensaje", "Si el correo existe, se ha enviado un código de recuperación."
        ));
    }

    /**
     * Paso 2: verifica el código de recuperación.
     */
    @PostMapping("/verificar-codigo")
    public ResponseEntity<Map<String, String>> verificarCodigo(
            @RequestBody VerificarCodigoRequestDTO request) {
        authService.verificarCodigo(request.getCorreo(), request.getCodigo());
        return ResponseEntity.ok(Map.of("mensaje", "Código verificado correctamente."));
    }

    /**
     * Paso 3: restablece la contraseña con el código verificado.
     */
    @PostMapping("/restablecer-password")
    public ResponseEntity<Map<String, String>> restablecerPassword(
            @RequestBody RestablecerPasswordRequestDTO request) {
        authService.restablecerPassword(
                request.getCorreo(), request.getCodigo(), request.getNewPassword());
        return ResponseEntity.ok(Map.of("mensaje", "Contraseña restablecida correctamente."));
    }

    /**
     * Cambio de contraseña con sesión iniciada (requiere JWT).
     */
    @PostMapping("/cambiar-password")
    public ResponseEntity<Map<String, String>> cambiarPassword(
            @RequestBody CambiarPasswordRequestDTO request,
            Authentication authentication) {
        authService.cambiarPassword(
                authentication, request.getUsuarioId(),
                request.getCurrentPassword(), request.getNewPassword());
        return ResponseEntity.ok(Map.of("mensaje", "Contraseña cambiada correctamente."));
    }
}
