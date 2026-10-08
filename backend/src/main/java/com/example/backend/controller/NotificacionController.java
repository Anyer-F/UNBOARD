package com.example.backend.controller;

import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.backend.dto.NotificacionRequestDTO;
import com.example.backend.dto.NotificacionResponseDTO;
import com.example.backend.entity.Notificacion;
import com.example.backend.repository.NotificacionRepository;
import com.example.backend.service.NotificacionService;
import com.example.backend.service.SeguridadService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/notificaciones")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class NotificacionController {

    private final NotificacionService notificacionService;
    private final SeguridadService seguridadService;
    private final NotificacionRepository notificacionRepository;

    @GetMapping("/usuario/{usuarioId}")
    public ResponseEntity<List<NotificacionResponseDTO>> listarPorUsuario(
            @PathVariable Long usuarioId,
            @RequestParam(value = "soloNoLeidas", required = false) Boolean soloNoLeidas) {
        // FASE B: cada usuario solo consulta sus propias notificaciones
        verificarUsuarioPropio(usuarioId);
        return ResponseEntity.ok(notificacionService.listarPorUsuario(usuarioId, soloNoLeidas));
    }

    @GetMapping("/usuario/{usuarioId}/conteo-no-leidas")
    public ResponseEntity<Map<String, Object>> contarNoLeidas(@PathVariable Long usuarioId) {
        verificarUsuarioPropio(usuarioId);
        long conteo = notificacionService.contarNoLeidas(usuarioId);
        return ResponseEntity.ok(Map.of("usuarioId", usuarioId, "noLeidas", conteo));
    }

    @PostMapping
    public ResponseEntity<NotificacionResponseDTO> crear(@RequestBody NotificacionRequestDTO request) {
        // FASE B: las notificaciones las genera el sistema internamente,
        // no se crean mediante la API pública
        throw new com.example.backend.config.AccesoDenegadoException(
                "La creación de notificaciones es interna del sistema.");
    }

    @PatchMapping("/{id}/leer")
    public ResponseEntity<NotificacionResponseDTO> marcarComoLeida(@PathVariable Long id) {
        verificarNotificacionPropia(id);
        return ResponseEntity.ok(notificacionService.marcarComoLeida(id));
    }

    @PatchMapping("/usuario/{usuarioId}/leer-todas")
    public ResponseEntity<Map<String, Object>> marcarTodasComoLeidas(@PathVariable Long usuarioId) {
        verificarUsuarioPropio(usuarioId);
        int totalActualizadas = notificacionService.marcarTodasComoLeidas(usuarioId);
        return ResponseEntity.ok(Map.of(
                "usuarioId", usuarioId,
                "mensaje", "Todas las notificaciones fueron marcadas como leídas.",
                "totalActualizadas", totalActualizadas
        ));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        verificarNotificacionPropia(id);
        notificacionService.eliminar(id);
        return ResponseEntity.noContent().build();
    }

    // ==================== VERIFICACIONES DE PERTENENCIA ====================

    private void verificarUsuarioPropio(Long usuarioId) {
        if (!seguridadService.usuarioActual().getId().equals(usuarioId)) {
            throw new com.example.backend.config.AccesoDenegadoException(
                    "No puede consultar las notificaciones de otro usuario.");
        }
    }

    private void verificarNotificacionPropia(Long notificacionId) {
        Notificacion notificacion = notificacionRepository.findById(notificacionId)
                .orElseThrow(() -> new RuntimeException("Notificación no encontrada con ID: " + notificacionId));
        if (notificacion.getUsuario() == null
                || !notificacion.getUsuario().getId().equals(seguridadService.usuarioActual().getId())) {
            throw new com.example.backend.config.AccesoDenegadoException(
                    "No puede modificar la notificación de otro usuario.");
        }
    }
}
