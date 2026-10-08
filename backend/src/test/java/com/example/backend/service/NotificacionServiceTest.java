package com.example.backend.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.example.backend.dto.NotificacionRequestDTO;
import com.example.backend.dto.NotificacionResponseDTO;
import com.example.backend.entity.Notificacion;
import com.example.backend.entity.TipoNotificacion;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.NotificacionRepository;
import com.example.backend.repository.UsuarioRepository;

@ExtendWith(MockitoExtension.class)
class NotificacionServiceTest {

    @Mock
    private NotificacionRepository notificacionRepository;

    @Mock
    private UsuarioRepository usuarioRepository;

    @Mock
    private FcmService fcmService;

    @InjectMocks
    private NotificacionService notificacionService;

    private Usuario usuario;
    private Notificacion notificacion;
    private NotificacionRequestDTO notificacionRequest;

    @BeforeEach
    void setUp() {
        usuario = Usuario.builder()
                .id(1L)
                .nombre("María")
                .correo("maria@example.com")
                .fcmToken("fcm-token-test-123")
                .build();

        notificacion = Notificacion.builder()
                .id(1L)
                .titulo("Nueva actividad asignada")
                .mensaje("Se te ha asignado una nueva actividad")
                .tipo(TipoNotificacion.ACTIVIDAD)
                .fechaCreacion(LocalDateTime.now())
                .leida(false)
                .idReferencia(1L)
                .tipoReferencia("ACTIVIDAD")
                .usuario(usuario)
                .build();

        notificacionRequest = NotificacionRequestDTO.builder()
                .usuarioId(1L)
                .titulo("Nueva actividad asignada")
                .mensaje("Se te ha asignado una nueva actividad")
                .tipo(TipoNotificacion.ACTIVIDAD)
                .idReferencia(1L)
                .tipoReferencia("ACTIVIDAD")
                .build();
    }

    // ==================== LISTAR ====================

    @Test
    void listarPorUsuario_debeRetornarNotificaciones() {
        when(notificacionRepository.findByUsuarioIdOrderByFechaCreacionDesc(1L))
                .thenReturn(List.of(notificacion));

        List<NotificacionResponseDTO> resultado = notificacionService.listarPorUsuario(1L, false);

        assertNotNull(resultado);
        assertEquals(1, resultado.size());
        assertEquals("Nueva actividad asignada", resultado.get(0).getTitulo());

        verify(notificacionRepository).findByUsuarioIdOrderByFechaCreacionDesc(1L);
    }

    @Test
    void listarPorUsuarioSoloNoLeidas_debeRetornarSoloNoLeidas() {
        when(notificacionRepository.findByUsuarioIdAndLeidaFalseOrderByFechaCreacionDesc(1L))
                .thenReturn(List.of(notificacion));

        List<NotificacionResponseDTO> resultado = notificacionService.listarPorUsuario(1L, true);

        assertNotNull(resultado);
        assertEquals(1, resultado.size());

        verify(notificacionRepository).findByUsuarioIdAndLeidaFalseOrderByFechaCreacionDesc(1L);
    }

    @Test
    void contarNoLeidas_debeRetornarConteoCorrecto() {
        when(notificacionRepository.countByUsuarioIdAndLeidaFalse(1L)).thenReturn(5L);

        long resultado = notificacionService.contarNoLeidas(1L);

        assertEquals(5L, resultado);
        verify(notificacionRepository).countByUsuarioIdAndLeidaFalse(1L);
    }

    // ==================== CREAR ====================

    @Test
    void crear_debeGuardarNotificacionCorrectamente() {
        when(usuarioRepository.findById(1L)).thenReturn(Optional.of(usuario));
        when(notificacionRepository.save(any(Notificacion.class))).thenReturn(notificacion);
        when(fcmService.enviarNotificacionPushData(anyString(), anyString(), anyString(), anyString(), anyLong()))
                .thenReturn(true);

        NotificacionResponseDTO resultado = notificacionService.crear(notificacionRequest);

        assertNotNull(resultado);
        assertEquals("Nueva actividad asignada", resultado.getTitulo());
        assertEquals(1L, resultado.getUsuarioId());

        verify(notificacionRepository).save(any(Notificacion.class));
    }

    @Test
    void crear_debeEnviarNotificacionPushSiUsuarioTieneToken() {
        when(usuarioRepository.findById(1L)).thenReturn(Optional.of(usuario));
        when(notificacionRepository.save(any(Notificacion.class))).thenReturn(notificacion);
        when(fcmService.enviarNotificacionPushData(anyString(), anyString(), anyString(), anyString(), anyLong()))
                .thenReturn(true);

        notificacionService.crear(notificacionRequest);

        verify(fcmService).enviarNotificacionPushData(
                eq("fcm-token-test-123"),
                eq("Nueva actividad asignada"),
                eq("Se te ha asignado una nueva actividad"),
                eq("ACTIVIDAD"),
                eq(1L)
        );
    }

    @Test
    void crear_debeLanzarExcepcionSiUsuarioNoExiste() {
        when(usuarioRepository.findById(99L)).thenReturn(Optional.empty());

        NotificacionRequestDTO requestInvalido = NotificacionRequestDTO.builder()
                .usuarioId(99L)
                .titulo("Título")
                .mensaje("Mensaje")
                .build();

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> notificacionService.crear(requestInvalido)
        );

        assertTrue(exception.getMessage().contains("Usuario no encontrado"));

        verify(usuarioRepository).findById(99L);
    }

    @Test
    void crear_debeLanzarExcepcionSiTituloEsNull() {
        NotificacionRequestDTO requestInvalido = NotificacionRequestDTO.builder()
                .usuarioId(1L)
                .titulo(null)
                .mensaje("Mensaje")
                .build();

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> notificacionService.crear(requestInvalido)
        );

        assertEquals("El título de la notificación es obligatorio.", exception.getMessage());
    }

    @Test
    void crear_debeLanzarExcepcionSiMensajeEsNull() {
        NotificacionRequestDTO requestInvalido = NotificacionRequestDTO.builder()
                .usuarioId(1L)
                .titulo("Título")
                .mensaje(null)
                .build();

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> notificacionService.crear(requestInvalido)
        );

        assertEquals("El mensaje de la notificación es obligatorio.", exception.getMessage());
    }

    // ==================== NOTIFICAR ====================

    @Test
    void notificar_debeGuardarNotificacionYEnviarPush() {
        when(notificacionRepository.save(any(Notificacion.class))).thenReturn(notificacion);
        when(fcmService.enviarNotificacionPushData(anyString(), anyString(), anyString(), anyString(), anyLong()))
                .thenReturn(true);

        notificacionService.notificar(usuario, "Título", "Mensaje", TipoNotificacion.GENERAL, 1L, "REFERENCIA");

        verify(notificacionRepository).save(any(Notificacion.class));
        verify(fcmService).enviarNotificacionPushData(anyString(), anyString(), anyString(), anyString(), anyLong());
    }

    @Test
    void notificar_debeRetornarSinErrorSiDestinatarioEsNull() {
        notificacionService.notificar(null, "Título", "Mensaje", TipoNotificacion.GENERAL, 1L, "REFERENCIA");

        verify(notificacionRepository, never()).save(any(Notificacion.class));
    }

    @Test
    void notificar_debeFuncionarSinTokenFcm() {
        Usuario usuarioSinToken = Usuario.builder()
                .id(2L)
                .nombre("Pedro")
                .correo("pedro@example.com")
                .fcmToken(null)
                .build();

        when(notificacionRepository.save(any(Notificacion.class))).thenReturn(notificacion);

        notificacionService.notificar(usuarioSinToken, "Título", "Mensaje", TipoNotificacion.GENERAL, 1L, "REFERENCIA");

        verify(notificacionRepository).save(any(Notificacion.class));
        verify(fcmService, never()).enviarNotificacionPushData(anyString(), anyString(), anyString(), anyString(), anyLong());
    }

    // ==================== MARCAR COMO LEIDA ====================

    @Test
    void marcarComoLeida_debeActualizarEstadoCorrectamente() {
        when(notificacionRepository.findById(1L)).thenReturn(Optional.of(notificacion));
        when(notificacionRepository.save(any(Notificacion.class))).thenAnswer(invocation -> {
            Notificacion n = invocation.getArgument(0);
            n.setLeida(true);
            return n;
        });

        NotificacionResponseDTO resultado = notificacionService.marcarComoLeida(1L);

        assertNotNull(resultado);
        assertTrue(resultado.getLeida());

        verify(notificacionRepository).findById(1L);
        verify(notificacionRepository).save(any(Notificacion.class));
    }

    @Test
    void marcarComoLeida_debeLanzarExcepcionSiNoExiste() {
        when(notificacionRepository.findById(99L)).thenReturn(Optional.empty());

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> notificacionService.marcarComoLeida(99L)
        );

        assertTrue(exception.getMessage().contains("Notificación no encontrada"));

        verify(notificacionRepository).findById(99L);
    }

    // ==================== MARCAR TODAS COMO LEIDAS ====================

    @Test
    void marcarTodasComoLeidas_debeActualizarTodasLasNotificaciones() {
        when(usuarioRepository.existsById(1L)).thenReturn(true);
        when(notificacionRepository.marcarTodasComoLeidasPorUsuario(1L)).thenReturn(5);

        int resultado = notificacionService.marcarTodasComoLeidas(1L);

        assertEquals(5, resultado);
        verify(notificacionRepository).marcarTodasComoLeidasPorUsuario(1L);
    }

    @Test
    void marcarTodasComoLeidas_debeLanzarExcepcionSiUsuarioNoExiste() {
        when(usuarioRepository.existsById(99L)).thenReturn(false);

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> notificacionService.marcarTodasComoLeidas(99L)
        );

        assertTrue(exception.getMessage().contains("Usuario no encontrado"));

        verify(usuarioRepository).existsById(99L);
    }

    // ==================== ELIMINAR ====================

    @Test
    void eliminar_debeEliminarNotificacionCorrectamente() {
        when(notificacionRepository.existsById(1L)).thenReturn(true);
        doNothing().when(notificacionRepository).deleteById(1L);

        notificacionService.eliminar(1L);

        verify(notificacionRepository).existsById(1L);
        verify(notificacionRepository).deleteById(1L);
    }

    @Test
    void eliminar_debeLanzarExcepcionSiNoExiste() {
        when(notificacionRepository.existsById(99L)).thenReturn(false);

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> notificacionService.eliminar(99L)
        );

        assertTrue(exception.getMessage().contains("Notificación no encontrada"));

        verify(notificacionRepository).existsById(99L);
    }
}
