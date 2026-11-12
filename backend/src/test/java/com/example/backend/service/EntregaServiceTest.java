package com.example.backend.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
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

import com.example.backend.entity.Actividad;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Asignacion;
import com.example.backend.entity.Documento;
import com.example.backend.entity.Entrega;
import com.example.backend.entity.EstadoActividad;
import com.example.backend.entity.EstadoEntrega;
import com.example.backend.entity.TipoActividad;
import com.example.backend.entity.TipoDocumento;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.AsignacionRepository;
import com.example.backend.repository.CartaRepository;
import com.example.backend.repository.DocumentoRepository;
import com.example.backend.repository.EntregaRepository;
import com.example.backend.repository.ExpedienteRepository;
import com.example.backend.repository.ObservacionRepository;
import com.example.backend.repository.SugerenciaRepository;

/**
 * Reglas de la entrega y su revisión.
 */
@ExtendWith(MockitoExtension.class)
class EntregaServiceTest {

    @Mock
    private AsignacionRepository asignacionRepository;
    @Mock
    private EntregaRepository entregaRepository;
    @Mock
    private DocumentoRepository documentoRepository;
    @Mock
    private CartaRepository cartaRepository;
    @Mock
    private SugerenciaRepository sugerenciaRepository;
    @Mock
    private ObservacionRepository observacionRepository;
    @Mock
    private ExpedienteRepository expedienteRepository;
    @Mock
    private DocumentoService documentoService;
    @Mock
    private NotificacionService notificacionService;
    @Mock
    private HistorialActividadService historialService;
    @Mock
    private SeguridadService seguridadService;
    @Mock
    private ConvertidorDTO convertidor;

    @InjectMocks
    private EntregaService entregaService;

    private Actividad tarea;
    private Asignacion asignacion;
    private Entrega borrador;

    @BeforeEach
    void setUp() {
        tarea = Actividad.builder().id(1L).tipo(TipoActividad.TAREA).titulo("Carta de agradecimiento")
                .fechaLimite(LocalDate.now().plusDays(5))
                .requiereFotografia(true).requiereDocumento(false).requiereCarta(false).build();
        Apadrinado apadrinado = Apadrinado.builder().id(2L)
                .usuario(Usuario.builder().id(3L).nombre("María").build()).build();
        asignacion = Asignacion.builder().id(4L).actividad(tarea).apadrinado(apadrinado)
                .estado(EstadoActividad.EN_PROGRESO).build();
        borrador = Entrega.builder().id(5L).asignacion(asignacion).version(1).estado(EstadoEntrega.BORRADOR).build();
    }

    @Test
    void enviar_sinLaFotografiaRequeridaEsRechazado() {
        when(seguridadService.verificarAsignacionDelApadrinado(4L)).thenReturn(asignacion);
        when(entregaRepository.findFirstByAsignacionIdOrderByVersionDesc(4L)).thenReturn(Optional.of(borrador));
        when(documentoRepository.findByEntregaId(5L)).thenReturn(List.of(
                Documento.builder().id(9L).tipoDocumento(TipoDocumento.DOCUMENTO).build()));
        when(cartaRepository.findByEntregaId(5L)).thenReturn(List.of());

        RuntimeException e = assertThrows(RuntimeException.class, () -> entregaService.enviar(4L, null));
        assertTrue(e.getMessage().contains("fotografía"));
        assertEquals(EstadoActividad.EN_PROGRESO, asignacion.getEstado());
    }

    @Test
    void enviar_conLoRequeridoPasaAEnviado() {
        when(seguridadService.verificarAsignacionDelApadrinado(4L)).thenReturn(asignacion);
        when(entregaRepository.findFirstByAsignacionIdOrderByVersionDesc(4L)).thenReturn(Optional.of(borrador));
        when(documentoRepository.findByEntregaId(5L)).thenReturn(List.of(
                Documento.builder().id(9L).tipoDocumento(TipoDocumento.FOTOGRAFIA).build()));
        when(cartaRepository.findByEntregaId(5L)).thenReturn(List.of());

        entregaService.enviar(4L, "Listo");

        assertEquals(EstadoActividad.ENVIADO, asignacion.getEstado());
        assertEquals(EstadoEntrega.ENVIADA, borrador.getEstado());
        assertEquals("Listo", borrador.getComentario());
        assertNotNull(asignacion.getFechaEnvio());
    }

    @Test
    void enviar_unaEntregaYaEnviadaNoSePuedeModificar() {
        asignacion.setEstado(EstadoActividad.ENVIADO);
        when(seguridadService.verificarAsignacionDelApadrinado(4L)).thenReturn(asignacion);

        assertThrows(RuntimeException.class, () -> entregaService.enviar(4L, null));
    }

    @Test
    void solicitarCorreccion_exigeSugerencias() {
        RuntimeException e = assertThrows(RuntimeException.class, () -> entregaService.solicitarCorreccion(4L, "  "));
        assertTrue(e.getMessage().contains("sugerencias"));
    }

    @Test
    void solicitarCorreccion_registraSugerenciaYCambiaEstado() {
        asignacion.setEstado(EstadoActividad.EN_REVISION);
        borrador.setEstado(EstadoEntrega.EN_REVISION);
        when(seguridadService.verificarAsignacionDelCoordinador(4L)).thenReturn(asignacion);
        when(entregaRepository.findFirstByAsignacionIdOrderByVersionDesc(4L)).thenReturn(Optional.of(borrador));
        when(cartaRepository.findByEntregaId(5L)).thenReturn(List.of());

        entregaService.solicitarCorreccion(4L, "Agrega una foto más clara");

        assertEquals(EstadoActividad.CORRECCION_SOLICITADA, asignacion.getEstado());
        assertEquals(EstadoEntrega.CORRECCION_SOLICITADA, borrador.getEstado());
        verify(sugerenciaRepository).save(any());
        verify(notificacionService).notificar(any(), eq("Corrección solicitada"), any(), any(), eq(4L), eq("ASIGNACION"));
    }

    @Test
    void borrador_despuesDeCorreccionCreaNuevaVersionConLosArchivosAnteriores() {
        asignacion.setEstado(EstadoActividad.CORRECCION_SOLICITADA);
        borrador.setEstado(EstadoEntrega.CORRECCION_SOLICITADA);
        Documento foto = Documento.builder().id(9L).tipoDocumento(TipoDocumento.FOTOGRAFIA).build();
        when(entregaRepository.findFirstByAsignacionIdOrderByVersionDesc(4L)).thenReturn(Optional.of(borrador));
        when(entregaRepository.save(any(Entrega.class))).thenAnswer(i -> i.getArgument(0));
        when(documentoRepository.findByEntregaId(5L)).thenReturn(List.of(foto));
        when(cartaRepository.findByEntregaId(5L)).thenReturn(List.of());

        Entrega nueva = entregaService.borrador(asignacion);

        assertEquals(2, nueva.getVersion());
        assertEquals(EstadoEntrega.BORRADOR, nueva.getEstado());
        verify(documentoService).copiarAEntrega(foto, nueva);
        // Sigue en corrección hasta que la vuelva a enviar
        assertEquals(EstadoActividad.CORRECCION_SOLICITADA, asignacion.getEstado());
    }

    @Test
    void anunciosNoAdmitenEntrega() {
        tarea.setTipo(TipoActividad.ANUNCIO);
        asignacion.setEstado(EstadoActividad.PUBLICADO);

        assertThrows(RuntimeException.class, () -> entregaService.borrador(asignacion));
    }

    private static <T> T eq(T valor) {
        return org.mockito.ArgumentMatchers.eq(valor);
    }
}
