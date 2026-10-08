package com.example.backend.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.dto.NotificacionRequestDTO;
import com.example.backend.dto.NotificacionResponseDTO;
import com.example.backend.entity.Notificacion;
import com.example.backend.entity.TipoNotificacion;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.NotificacionRepository;
import com.example.backend.repository.UsuarioRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class NotificacionService {

    private final NotificacionRepository notificacionRepository;
    private final UsuarioRepository usuarioRepository;
    private final FcmService fcmService;

    @Transactional(readOnly = true)
    public List<NotificacionResponseDTO> listarPorUsuario(Long usuarioId, Boolean soloNoLeidas) {
        List<Notificacion> lista;
        if (Boolean.TRUE.equals(soloNoLeidas)) {
            lista = notificacionRepository.findByUsuarioIdAndLeidaFalseOrderByFechaCreacionDesc(usuarioId);
        } else {
            lista = notificacionRepository.findByUsuarioIdOrderByFechaCreacionDesc(usuarioId);
        }
        return lista.stream().map(this::convertirAResponseDTO).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public long contarNoLeidas(Long usuarioId) {
        return notificacionRepository.countByUsuarioIdAndLeidaFalse(usuarioId);
    }

    @Transactional
    public NotificacionResponseDTO crear(NotificacionRequestDTO dto) {
        if (dto.getUsuarioId() == null) {
            throw new RuntimeException("El ID de usuario destinatario es obligatorio.");
        }
        if (dto.getTitulo() == null || dto.getTitulo().isBlank()) {
            throw new RuntimeException("El título de la notificación es obligatorio.");
        }
        if (dto.getMensaje() == null || dto.getMensaje().isBlank()) {
            throw new RuntimeException("El mensaje de la notificación es obligatorio.");
        }

        Usuario usuario = usuarioRepository.findById(dto.getUsuarioId())
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado con ID: " + dto.getUsuarioId()));

        Notificacion notificacion = Notificacion.builder()
                .titulo(dto.getTitulo())
                .mensaje(dto.getMensaje())
                .tipo(dto.getTipo() != null ? dto.getTipo() : TipoNotificacion.GENERAL)
                .fechaCreacion(LocalDateTime.now())
                .leida(false)
                .idReferencia(dto.getIdReferencia())
                .tipoReferencia(dto.getTipoReferencia())
                .usuario(usuario)
                .build();

        Notificacion guardada = notificacionRepository.save(notificacion);

        // Enviar notificación push si el usuario tiene token FCM
        if (usuario.getFcmToken() != null && !usuario.getFcmToken().isEmpty()) {
            fcmService.enviarNotificacionPushData(
                    usuario.getFcmToken(),
                    dto.getTitulo(),
                    dto.getMensaje(),
                    dto.getTipo() != null ? dto.getTipo().name() : "GENERAL",
                    guardada.getId()
            );
        }

        return convertirAResponseDTO(guardada);
    }

    @Transactional
    public void notificar(Usuario destinatario, String titulo, String mensaje, TipoNotificacion tipo, Long idReferencia, String tipoReferencia) {
        if (destinatario == null) {
            return;
        }

        Notificacion notificacion = Notificacion.builder()
                .titulo(titulo)
                .mensaje(mensaje)
                .tipo(tipo != null ? tipo : TipoNotificacion.GENERAL)
                .fechaCreacion(LocalDateTime.now())
                .leida(false)
                .idReferencia(idReferencia)
                .tipoReferencia(tipoReferencia)
                .usuario(destinatario)
                .build();

        Notificacion guardada = notificacionRepository.save(notificacion);

        // Enviar notificación push si el usuario tiene token FCM
        if (destinatario.getFcmToken() != null && !destinatario.getFcmToken().isEmpty()) {
            fcmService.enviarNotificacionPushData(
                    destinatario.getFcmToken(),
                    titulo,
                    mensaje,
                    tipo != null ? tipo.name() : "GENERAL",
                    guardada.getId()
            );
        }
    }

    @Transactional
    public NotificacionResponseDTO marcarComoLeida(Long notificacionId) {
        Notificacion notificacion = notificacionRepository.findById(notificacionId)
                .orElseThrow(() -> new RuntimeException("Notificación no encontrada con ID: " + notificacionId));

        notificacion.setLeida(true);
        Notificacion actualizada = notificacionRepository.save(notificacion);
        return convertirAResponseDTO(actualizada);
    }

    @Transactional
    public int marcarTodasComoLeidas(Long usuarioId) {
        if (!usuarioRepository.existsById(usuarioId)) {
            throw new RuntimeException("Usuario no encontrado con ID: " + usuarioId);
        }
        return notificacionRepository.marcarTodasComoLeidasPorUsuario(usuarioId);
    }

    @Transactional
    public void eliminar(Long notificacionId) {
        if (!notificacionRepository.existsById(notificacionId)) {
            throw new RuntimeException("Notificación no encontrada con ID: " + notificacionId);
        }
        notificacionRepository.deleteById(notificacionId);
    }

    public NotificacionResponseDTO convertirAResponseDTO(Notificacion notificacion) {
        Long usuarioId = null;
        String usuarioNombre = null;
        if (notificacion.getUsuario() != null) {
            usuarioId = notificacion.getUsuario().getId();
            usuarioNombre = notificacion.getUsuario().getNombre();
        }

        return NotificacionResponseDTO.builder()
                .id(notificacion.getId())
                .titulo(notificacion.getTitulo())
                .mensaje(notificacion.getMensaje())
                .tipo(notificacion.getTipo())
                .fechaCreacion(notificacion.getFechaCreacion())
                .leida(notificacion.getLeida())
                .idReferencia(notificacion.getIdReferencia())
                .tipoReferencia(notificacion.getTipoReferencia())
                .usuarioId(usuarioId)
                .usuarioNombre(usuarioNombre)
                .build();
    }
}
