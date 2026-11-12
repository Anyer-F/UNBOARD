package com.example.backend.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.example.backend.config.ConfirmacionRequeridaException;
import com.example.backend.dto.ActividadRequestDTO;
import com.example.backend.entity.Actividad;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Asignacion;
import com.example.backend.entity.Comunidad;
import com.example.backend.entity.Coordinador;
import com.example.backend.entity.EstadoActividad;
import com.example.backend.entity.EstadoEntrega;
import com.example.backend.entity.Modulo;
import com.example.backend.entity.TipoActividad;
import com.example.backend.entity.TipoNotificacion;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ActividadRepository;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.AsignacionRepository;
import com.example.backend.repository.CartaRepository;
import com.example.backend.repository.ComunidadRepository;
import com.example.backend.repository.DocumentoRepository;
import com.example.backend.repository.EntregaRepository;
import com.example.backend.repository.ExportacionRepository;
import com.example.backend.repository.HistorialActividadRepository;
import com.example.backend.repository.ModuloRepository;
import com.example.backend.repository.ObservacionRepository;

/**
 * Creación, asignación y eliminación de actividades.
 */
@ExtendWith(MockitoExtension.class)
class ActividadServiceTest {

    @Mock
    private ActividadRepository actividadRepository;
    @Mock
    private AsignacionRepository asignacionRepository;
    @Mock
    private EntregaRepository entregaRepository;
    @Mock
    private ApadrinadoRepository apadrinadoRepository;
    @Mock
    private ComunidadRepository comunidadRepository;
    @Mock
    private ModuloRepository moduloRepository;
    @Mock
    private DocumentoRepository documentoRepository;
    @Mock
    private CartaRepository cartaRepository;
    @Mock
    private HistorialActividadRepository historialRepository;
    @Mock
    private ExportacionRepository exportacionRepository;
    @Mock
    private ObservacionRepository observacionRepository;
    @Mock
    private DocumentoService documentoService;
    @Mock
    private ModuloService moduloService;
    @Mock
    private NotificacionService notificacionService;
    @Mock
    private HistorialActividadService historialService;
    @Mock
    private SeguridadService seguridadService;
    @Mock
    private ConvertidorDTO convertidor;

    @InjectMocks
    private ActividadService actividadService;

    private Comunidad comunidad;
    private Modulo modulo;
    private Coordinador coordinador;
    private Apadrinado maria;
    private Apadrinado jose;

    @BeforeEach
    void setUp() {
        comunidad = Comunidad.builder().id(1L).nombre("Chiantla").build();
        modulo = Modulo.builder().id(10L).comunidad(comunidad).nombre("Módulo 1").orden(1).build();
        coordinador = Coordinador.builder().id(5L)
                .usuario(Usuario.builder().id(1L).nombre("Carlos").build())
                .comunidad(comunidad).comunidades(new ArrayList<>()).build();
        maria = Apadrinado.builder().id(21L).comunidad(comunidad)
                .usuario(Usuario.builder().id(31L).nombre("María").build()).build();
        jose = Apadrinado.builder().id(22L).comunidad(comunidad)
                .usuario(Usuario.builder().id(32L).nombre("José").build()).build();
    }

    private void coordinadorEnSuComunidad() {
        when(seguridadService.requerirCoordinadorActual()).thenReturn(coordinador);
        when(comunidadRepository.findById(1L)).thenReturn(Optional.of(comunidad));
        when(moduloService.resolverModulo(comunidad, null)).thenReturn(modulo);
    }

    @Test
    void crearTarea_sinFechaLimiteEsRechazada() {
        coordinadorEnSuComunidad();
        ActividadRequestDTO dto = ActividadRequestDTO.builder()
                .tipo(TipoActividad.TAREA).titulo("Carta").comunidadId(1L).asignarAComunidad(true).build();

        RuntimeException e = assertThrows(RuntimeException.class, () -> actividadService.crear(dto));
        assertTrue(e.getMessage().contains("fecha límite"));
    }

    @Test
    void crearTarea_paraTodaLaComunidadAsignaACadaApadrinado() {
        coordinadorEnSuComunidad();
        when(apadrinadoRepository.findByComunidadId(1L)).thenReturn(List.of(maria, jose));
        when(actividadRepository.save(any(Actividad.class))).thenAnswer(i -> {
            Actividad a = i.getArgument(0);
            a.setId(100L);
            return a;
        });
        when(asignacionRepository.save(any(Asignacion.class))).thenAnswer(i -> i.getArgument(0));

        actividadService.crear(ActividadRequestDTO.builder()
                .tipo(TipoActividad.TAREA).titulo("Carta").comunidadId(1L)
                .fechaLimite(LocalDate.now().plusDays(7)).asignarAComunidad(true).build());

        verify(asignacionRepository, times(2)).save(argThat(s -> s.getEstado() == EstadoActividad.PENDIENTE));
        verify(notificacionService, times(2)).notificar(any(), any(), any(),
                org.mockito.ArgumentMatchers.eq(TipoNotificacion.NUEVA_ACTIVIDAD), any(), any());
    }

    @Test
    void crearAnuncio_quedaPublicadoSinFechaNiRequisitos() {
        coordinadorEnSuComunidad();
        when(apadrinadoRepository.findAllById(any())).thenReturn(List.of(maria));
        when(actividadRepository.save(any(Actividad.class))).thenAnswer(i -> i.getArgument(0));
        when(asignacionRepository.save(any(Asignacion.class))).thenAnswer(i -> i.getArgument(0));

        actividadService.crear(ActividadRequestDTO.builder()
                .tipo(TipoActividad.ANUNCIO).titulo("Reunión").comunidadId(1L)
                .fechaLimite(LocalDate.now().plusDays(3)).requiereFotografia(true)
                .asignarAComunidad(false).apadrinadoIds(List.of(21L)).build());

        verify(actividadRepository).save(argThat(a -> a.getFechaLimite() == null
                && !a.getRequiereFotografia() && a.getTipo() == TipoActividad.ANUNCIO));
        verify(asignacionRepository).save(argThat(s -> s.getEstado() == EstadoActividad.PUBLICADO));
        verify(notificacionService).notificar(any(), any(), any(),
                org.mockito.ArgumentMatchers.eq(TipoNotificacion.NUEVO_ANUNCIO), any(), any());
    }

    @Test
    void crear_rechazaApadrinadosDeOtraComunidad() {
        coordinadorEnSuComunidad();
        Apadrinado ajeno = Apadrinado.builder().id(40L).comunidad(Comunidad.builder().id(9L).build())
                .usuario(Usuario.builder().nombre("Ajeno").build()).build();
        when(apadrinadoRepository.findAllById(any())).thenReturn(List.of(ajeno));

        RuntimeException e = assertThrows(RuntimeException.class, () -> actividadService.crear(
                ActividadRequestDTO.builder().tipo(TipoActividad.ANUNCIO).titulo("Aviso").comunidadId(1L)
                        .asignarAComunidad(false).apadrinadoIds(List.of(40L)).build()));
        assertTrue(e.getMessage().contains("no pertenece a la comunidad"));
        verify(actividadRepository, never()).save(any());
    }

    @Test
    void eliminar_conEntregasRequiereConfirmacionYEsLogica() {
        Actividad actividad = Actividad.builder().id(100L).titulo("Carta").tipo(TipoActividad.TAREA)
                .comunidad(comunidad).eliminada(false).build();
        when(seguridadService.verificarActividadPropia(100L)).thenReturn(actividad);
        when(entregaRepository.existsByAsignacionActividadIdAndEstadoNot(100L, EstadoEntrega.BORRADOR)).thenReturn(true);

        assertThrows(ConfirmacionRequeridaException.class, () -> actividadService.eliminar(100L, false));
        assertFalse(actividad.getEliminada());

        assertEquals("LOGICA", actividadService.eliminar(100L, true));
        assertTrue(actividad.getEliminada());
        verify(actividadRepository, never()).eliminarPorId(any());
    }

    @Test
    void eliminar_sinEntregasEsDefinitiva() {
        Actividad actividad = Actividad.builder().id(100L).titulo("Aviso").tipo(TipoActividad.ANUNCIO)
                .comunidad(comunidad).eliminada(false).build();
        when(seguridadService.verificarActividadPropia(100L)).thenReturn(actividad);
        when(entregaRepository.existsByAsignacionActividadIdAndEstadoNot(100L, EstadoEntrega.BORRADOR)).thenReturn(false);

        assertEquals("DEFINITIVA", actividadService.eliminar(100L, false));
        verify(historialRepository).desvincularActividad(100L);
        verify(asignacionRepository).eliminarPorActividad(100L);
        verify(actividadRepository).eliminarPorId(100L);
    }
}
