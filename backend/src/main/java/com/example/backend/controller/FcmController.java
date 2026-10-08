package com.example.backend.controller;

import java.time.LocalDateTime;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.backend.dto.FcmTokenRequestDTO;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.UsuarioRepository;
import com.example.backend.service.FcmService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/fcm")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class FcmController {

    private final UsuarioRepository usuarioRepository;
    private final FcmService fcmService;

    @PostMapping("/registrar-token")
    public ResponseEntity<String> registrarToken(
            @RequestBody FcmTokenRequestDTO request,
            Authentication authentication) {

        if (authentication == null || !authentication.isAuthenticated()) {
            return ResponseEntity.status(401).body("No autenticado");
        }

        try {
            // FASE B: el subject del JWT es el correo del usuario
            Usuario usuario = usuarioRepository.findByCorreo(authentication.getName())
                    .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));

            usuario.setFcmToken(request.getFcmToken());
            usuario.setFcmTokenActualizado(LocalDateTime.now());
            usuarioRepository.save(usuario);

            // Suscribir al usuario a un tema general para notificaciones broadcast
            fcmService.suscribirATema(request.getFcmToken(), "todos");

            return ResponseEntity.ok("Token FCM registrado correctamente");
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error al registrar token: " + e.getMessage());
        }
    }

    @PostMapping("/suscribir-tema")
    public ResponseEntity<String> suscribirATema(
            @RequestBody FcmTokenRequestDTO request,
            Authentication authentication) {

        if (authentication == null || !authentication.isAuthenticated()) {
            return ResponseEntity.status(401).body("No autenticado");
        }

        try {
            // FASE B: el subject del JWT es el correo del usuario
            Usuario usuario = usuarioRepository.findByCorreo(authentication.getName())
                    .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));

            String tema = request.getDispositivo() != null ? request.getDispositivo() : "todos";
            boolean exito = fcmService.suscribirATema(request.getFcmToken(), tema);

            if (exito) {
                return ResponseEntity.ok("Suscripción al tema '" + tema + "' exitosa");
            } else {
                return ResponseEntity.badRequest().body("Error al suscribir al tema");
            }
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error: " + e.getMessage());
        }
    }
}
