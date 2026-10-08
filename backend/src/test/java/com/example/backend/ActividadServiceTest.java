package com.example.backend.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.example.backend.dto.ActividadEstadoDTO;
import com.example.backend.dto.ActividadResponseDTO;
import com.example.backend.entity.Actividad;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.EstadoActividad;
import com.example.backend.entity.TipoNotificacion;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ActividadRepository;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.CoordinadorRepository;
import com.example.backend.repository.DocumentoRepository;
import com.example.backend.repository.HistorialActividadRepository;
import com.example.backend.repository.UsuarioRepository;

@ExtendWith(MockitoExtension.class)
class ActividadServiceTest {

    @Mock
    private ActividadRepository actividadRepository;

    @Mock
    private CoordinadorRepository coordinadorRepository;

    @Mock
    private ApadrinadoRepository apadrinadoRepository;

    @Mock
    private UsuarioRepository usuarioRepository;

    @Mock
    private DocumentoRepository documentoRepository;

    @Mock
    private HistorialActividadRepository historialActividadRepository;

    @Mock
    private FileStorageService fileStorageService;

    @Mock
    private NotificacionService notificacionService;

    @Mock
    private HistorialActividadService historialActividadService;

    @InjectMocks
    private ActividadService actividadService;

    private Actividad actividad;

    @BeforeEach
    void setUp() {
        actividad = Actividad.builder()
                .id(1L)
                .titulo("Actividad de prueba")
                .descripcion("Descripción de prueba")
                .estado(EstadoActividad.PENDIENTE)
                .requiereDocumento(false)
                .requiereFotografia(false)
                .build();
    }

    @Test
    void listarTodas_debeRetornarListaDeActividades() {

        when(actividadRepository.findAll())
                .thenReturn(List.of(actividad));

        List<ActividadResponseDTO> resultado =
                actividadService.listarTodas();

        assertNotNull(resultado);
        assertEquals(1, resultado.size());
        assertEquals("Actividad de prueba", resultado.get(0).getTitulo());

        verify(actividadRepository).findAll();
    }

    @Test
    void obtenerPorId_debeRetornarActividadExistente() {

        when(actividadRepository.findById(1L))
                .thenReturn(Optional.of(actividad));

        ActividadResponseDTO resultado =
                actividadService.obtenerPorId(1L);

        assertNotNull(resultado);
        assertEquals(1L, resultado.getId());
        assertEquals("Actividad de prueba", resultado.getTitulo());
        assertEquals(EstadoActividad.PENDIENTE, resultado.getEstado());

        verify(actividadRepository).findById(1L);
    }

    @Test
    void obtenerPorId_debeLanzarExcepcionSiNoExiste() {

        when(actividadRepository.findById(99L))
                .thenReturn(Optional.empty());

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> actividadService.obtenerPorId(99L)
        );

        assertEquals(
                "Actividad no encontrada con ID: 99",
                exception.getMessage()
        );

        verify(actividadRepository).findById(99L);
    }

    @Test
    void eliminar_debeEliminarActividadCorrectamente() {

        when(actividadRepository.findById(1L))
                .thenReturn(Optional.of(actividad));

        when(documentoRepository.findByActividadId(1L))
                .thenReturn(List.of());

        actividadService.eliminar(1L);

        verify(documentoRepository).findByActividadId(1L);
        verify(historialActividadRepository).deleteByActividadId(1L);
        verify(actividadRepository).delete(actividad);
    }

    // ==================== FASE E: EN_REVISIÓN Y VENCIDO ====================

    @Test
    void cambiarEstado_debeIniciarRevisionDesdeEntregadaYNotificar() {
        Usuario usuarioAp = mock(Usuario.class);
        actividad.setApadrinado(
                Apadrinado.builder().id(1L).usuario(usuarioAp).build());
        actividad.setEstado(EstadoActividad.ENTREGADA);

        ActividadEstadoDTO dto = new ActividadEstadoDTO();
        dto.setEstado(EstadoActividad.EN_REVISION);

        when(actividadRepository.findById(1L))
                .thenReturn(Optional.of(actividad));
        when(actividadRepository.save(any(Actividad.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        ActividadResponseDTO resultado = actividadService.cambiarEstado(1L, dto);

        assertEquals(EstadoActividad.EN_REVISION, resultado.getEstado());
        verify(notificacionService).notificar(
                eq(usuarioAp),
                eq("Documento en revisión"),
                anyString(),
                eq(TipoNotificacion.ACTIVIDAD_EN_REVISION),
                eq(1L),
                eq("ACTIVIDAD"));
    }

    @Test
    void cambiarEstado_enRevisionDesdePendiente_lanzaExcepcion() {
        ActividadEstadoDTO dto = new ActividadEstadoDTO();
        dto.setEstado(EstadoActividad.EN_REVISION);

        when(actividadRepository.findById(1L))
                .thenReturn(Optional.of(actividad));

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> actividadService.cambiarEstado(1L, dto)
        );

        assertTrue(exception.getMessage()
                .contains("Solo se puede iniciar la revisión"));
    }

    @Test
    void cambiarEstado_vencidoViaPatch_lanzaExcepcion() {
        ActividadEstadoDTO dto = new ActividadEstadoDTO();
        dto.setEstado(EstadoActividad.VENCIDO);

        when(actividadRepository.findById(1L))
                .thenReturn(Optional.of(actividad));

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> actividadService.cambiarEstado(1L, dto)
        );

        assertTrue(exception.getMessage()
                .contains("VENCIDO se asigna automáticamente"));
    }

    @Test
    void marcarVencido_debeMarcarActividadConFechaLimitePasada() {
        Usuario usuarioAp = mock(Usuario.class);
        actividad.setApadrinado(
                Apadrinado.builder().id(1L).usuario(usuarioAp).build());
        actividad.setEstado(EstadoActividad.PENDIENTE);
        actividad.setFechaLimite(LocalDate.now().minusDays(1));

        when(actividadRepository.findById(1L))
                .thenReturn(Optional.of(actividad));

        ActividadResponseDTO resultado = actividadService.marcarVencido(1L);

        assertEquals(EstadoActividad.VENCIDO, resultado.getEstado());
        verify(historialActividadService).registrarCambio(
                eq(actividad),
                eq(EstadoActividad.PENDIENTE),
                eq(EstadoActividad.VENCIDO),
                eq("VENCIMIENTO"),
                anyString(),
                any());
        verify(notificacionService).notificar(
                eq(usuarioAp),
                eq("Actividad vencida"),
                anyString(),
                eq(TipoNotificacion.ACTIVIDAD_VENCIDA),
                eq(1L),
                eq("ACTIVIDAD"));
    }

    @Test
    void marcarVencido_conFechaLimiteFutura_lanzaExcepcion() {
        actividad.setEstado(EstadoActividad.PENDIENTE);
        actividad.setFechaLimite(LocalDate.now().plusDays(5));

        when(actividadRepository.findById(1L))
                .thenReturn(Optional.of(actividad));

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> actividadService.marcarVencido(1L)
        );

        assertTrue(exception.getMessage().contains("aún no ha vencido"));
    }

    @Test
    void marcarVencido_conActividadEntregada_lanzaExcepcion() {
        actividad.setEstado(EstadoActividad.ENTREGADA);
        actividad.setFechaLimite(LocalDate.now().minusDays(1));

        when(actividadRepository.findById(1L))
                .thenReturn(Optional.of(actividad));

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> actividadService.marcarVencido(1L)
        );

        assertTrue(exception.getMessage()
                .contains("Solo las actividades pendientes"));
    }

    @Test
    void marcarVencidasDelCoordinador_debeMarcarSoloLasVencidas() {
        Actividad vencible = Actividad.builder()
                .id(10L)
                .titulo("Actividad vencible")
                .estado(EstadoActividad.PENDIENTE)
                .fechaLimite(LocalDate.now().minusDays(2))
                .build();
        Actividad vigente = Actividad.builder()
                .id(11L)
                .titulo("Actividad vigente")
                .estado(EstadoActividad.PENDIENTE)
                .fechaLimite(LocalDate.now().plusDays(3))
                .build();

        when(actividadRepository.findByCoordinadorIdAndEstadoIn(eq(5L), anyList()))
                .thenReturn(List.of(vencible, vigente));

        List<ActividadResponseDTO> resultado =
                actividadService.marcarVencidasDelCoordinador(5L);

        assertEquals(1, resultado.size());
        assertEquals(10L, resultado.get(0).getId());
        assertEquals(EstadoActividad.VENCIDO, resultado.get(0).getEstado());
        verify(actividadRepository).save(vencible);
        verify(actividadRepository, never()).save(vigente);
    }
}