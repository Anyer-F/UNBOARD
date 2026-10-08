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

import com.example.backend.dto.CartaRequestDTO;
import com.example.backend.dto.CartaResponseDTO;
import com.example.backend.entity.Actividad;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Carta;
import com.example.backend.entity.Carta.EstadoCarta;
import com.example.backend.entity.Carta.TipoCarta;
import com.example.backend.entity.Expediente;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ActividadRepository;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.CartaRepository;
import com.example.backend.repository.ExpedienteRepository;
import com.example.backend.repository.UsuarioRepository;

@ExtendWith(MockitoExtension.class)
class CartaServiceTest {

    @Mock
    private CartaRepository cartaRepository;

    @Mock
    private ApadrinadoRepository apadrinadoRepository;

    @Mock
    private ExpedienteRepository expedienteRepository;

    @Mock
    private ActividadRepository actividadRepository;

    @Mock
    private UsuarioRepository usuarioRepository;

    @InjectMocks
    private CartaService cartaService;

    private Carta carta;
    private CartaRequestDTO cartaRequest;
    private Usuario usuario;
    private Apadrinado apadrinado;
    private Expediente expediente;

    @BeforeEach
    void setUp() {
        usuario = Usuario.builder()
                .id(1L)
                .nombre("Juan")
                .correo("juan@example.com")
                .build();

        apadrinado = Apadrinado.builder()
                .id(1L)
                .usuario(usuario)
                .build();

        expediente = Expediente.builder()
                .id(1L)
                .build();

        carta = Carta.builder()
                .id(1L)
                .titulo("Carta de agradecimiento")
                .contenido("Querido padrino, gracias por su apoyo...")
                .tipoCarta(TipoCarta.CARTA_PADRINO)
                .estado(EstadoCarta.BORRADOR)
                .fechaCreacion(LocalDateTime.now())
                .expediente(expediente)
                .apadrinado(apadrinado)
                .escritoPor(usuario)
                .build();

        cartaRequest = CartaRequestDTO.builder()
                .titulo("Carta de agradecimiento")
                .contenido("Querido padrino, gracias por su apoyo...")
                .apadrinadoId(1L)
                .tipoCarta("CARTA_PADRINO")
                .build();
    }

    // ==================== LISTAR ====================

    @Test
    void listarTodas_debeRetornarListaDeCartas() {
        when(cartaRepository.findAll()).thenReturn(List.of(carta));

        List<CartaResponseDTO> resultado = cartaService.listarTodas();

        assertNotNull(resultado);
        assertEquals(1, resultado.size());
        assertEquals("Carta de agradecimiento", resultado.get(0).getTitulo());

        verify(cartaRepository).findAll();
    }

    @Test
    void listarPorApadrinado_debeRetornarCartasDelApadrinado() {
        when(cartaRepository.findByApadrinadoId(1L)).thenReturn(List.of(carta));

        List<CartaResponseDTO> resultado = cartaService.listarPorApadrinado(1L);

        assertNotNull(resultado);
        assertEquals(1, resultado.size());
        assertEquals(1L, resultado.get(0).getApadrinadoId());

        verify(cartaRepository).findByApadrinadoId(1L);
    }

    @Test
    void listarPorExpediente_debeRetornarCartasDelExpediente() {
        when(cartaRepository.findByExpedienteId(1L)).thenReturn(List.of(carta));

        List<CartaResponseDTO> resultado = cartaService.listarPorExpediente(1L);

        assertNotNull(resultado);
        assertEquals(1, resultado.size());

        verify(cartaRepository).findByExpedienteId(1L);
    }

    @Test
    void listarPorEstado_debeRetornarCartasConEseEstado() {
        when(cartaRepository.findByEstado(EstadoCarta.BORRADOR)).thenReturn(List.of(carta));

        List<CartaResponseDTO> resultado = cartaService.listarPorEstado(EstadoCarta.BORRADOR);

        assertNotNull(resultado);
        assertEquals(1, resultado.size());
        assertEquals(EstadoCarta.BORRADOR, resultado.get(0).getEstado());

        verify(cartaRepository).findByEstado(EstadoCarta.BORRADOR);
    }

    // ==================== OBTENER POR ID ====================

    @Test
    void obtenerPorId_debeRetornarCartaExistente() {
        when(cartaRepository.findById(1L)).thenReturn(Optional.of(carta));

        CartaResponseDTO resultado = cartaService.obtenerPorId(1L);

        assertNotNull(resultado);
        assertEquals(1L, resultado.getId());
        assertEquals("Carta de agradecimiento", resultado.getTitulo());
        assertEquals("CARTA_PADRINO", resultado.getTipoCarta().name());

        verify(cartaRepository).findById(1L);
    }

    @Test
    void obtenerPorId_debeLanzarExcepcionSiNoExiste() {
        when(cartaRepository.findById(99L)).thenReturn(Optional.empty());

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> cartaService.obtenerPorId(99L)
        );

        assertEquals("Carta no encontrada con id: 99", exception.getMessage());

        verify(cartaRepository).findById(99L);
    }

    // ==================== CREAR ====================

    @Test
    void crear_debeGuardarCartaCorrectamente() {
        when(apadrinadoRepository.findById(1L)).thenReturn(Optional.of(apadrinado));
        when(usuarioRepository.findById(1L)).thenReturn(Optional.of(usuario));
        when(expedienteRepository.findByApadrinadoId(1L)).thenReturn(Optional.of(expediente));
        when(cartaRepository.save(any(Carta.class))).thenReturn(carta);

        CartaResponseDTO resultado = cartaService.crear(cartaRequest, 1L);

        assertNotNull(resultado);
        assertEquals("Carta de agradecimiento", resultado.getTitulo());
        assertEquals(EstadoCarta.BORRADOR, resultado.getEstado());

        verify(apadrinadoRepository).findById(1L);
        verify(usuarioRepository).findById(1L);
        verify(expedienteRepository).findByApadrinadoId(1L);
        verify(cartaRepository).save(any(Carta.class));
    }

    @Test
    void crear_debeLanzarExcepcionSiApadrinadoNoExiste() {
        when(apadrinadoRepository.findById(99L)).thenReturn(Optional.empty());

        CartaRequestDTO requestInvalido = CartaRequestDTO.builder()
                .titulo("Carta")
                .contenido("Contenido")
                .apadrinadoId(99L)
                .build();

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> cartaService.crear(requestInvalido, 1L)
        );

        assertTrue(exception.getMessage().contains("Apadrinado no encontrado"));

        verify(apadrinadoRepository).findById(99L);
    }

    @Test
    void crear_debeLanzarExcepcionSiUsuarioNoExiste() {
        when(apadrinadoRepository.findById(1L)).thenReturn(Optional.of(apadrinado));
        when(usuarioRepository.findById(99L)).thenReturn(Optional.empty());

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> cartaService.crear(cartaRequest, 99L)
        );

        assertTrue(exception.getMessage().contains("Usuario no encontrado"));

        verify(usuarioRepository).findById(99L);
    }

    @Test
    void crear_debeLanzarExcepcionSiNoExisteExpediente() {
        when(apadrinadoRepository.findById(1L)).thenReturn(Optional.of(apadrinado));
        when(usuarioRepository.findById(1L)).thenReturn(Optional.of(usuario));
        when(expedienteRepository.findByApadrinadoId(1L)).thenReturn(Optional.empty());

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> cartaService.crear(cartaRequest, 1L)
        );

        assertTrue(exception.getMessage().contains("No existe expediente"));

        verify(expedienteRepository).findByApadrinadoId(1L);
    }

    // ==================== ACTUALIZAR ====================

    @Test
    void actualizar_debeModificarCartaCorrectamente() {
        when(cartaRepository.findById(1L)).thenReturn(Optional.of(carta));
        when(cartaRepository.save(any(Carta.class))).thenReturn(carta);

        CartaRequestDTO updateRequest = CartaRequestDTO.builder()
                .titulo("Título actualizado")
                .contenido("Contenido actualizado")
                .build();

        CartaResponseDTO resultado = cartaService.actualizar(1L, updateRequest);

        assertNotNull(resultado);
        verify(cartaRepository).findById(1L);
        verify(cartaRepository).save(any(Carta.class));
    }

    @Test
    void actualizar_debeLanzarExcepcionSiNoExiste() {
        when(cartaRepository.findById(99L)).thenReturn(Optional.empty());

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> cartaService.actualizar(99L, cartaRequest)
        );

        assertEquals("Carta no encontrada con id: 99", exception.getMessage());

        verify(cartaRepository).findById(99L);
    }

    // ==================== ENVIAR CARTA ====================

    @Test
    void enviarCarta_debeCambiarEstadoAEnviada() {
        when(cartaRepository.findById(1L)).thenReturn(Optional.of(carta));
        when(cartaRepository.save(any(Carta.class))).thenAnswer(invocation -> {
            Carta c = invocation.getArgument(0);
            c.setEstado(EstadoCarta.ENVIADA);
            c.setFechaEnvio(LocalDateTime.now());
            return c;
        });

        CartaResponseDTO resultado = cartaService.enviarCarta(1L);

        assertNotNull(resultado);
        assertEquals(EstadoCarta.ENVIADA, resultado.getEstado());
        assertNotNull(resultado.getFechaEnvio());

        verify(cartaRepository).findById(1L);
        verify(cartaRepository).save(any(Carta.class));
    }

    @Test
    void enviarCarta_debeLanzarExcepcionSiNoExiste() {
        when(cartaRepository.findById(99L)).thenReturn(Optional.empty());

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> cartaService.enviarCarta(99L)
        );

        assertEquals("Carta no encontrada con id: 99", exception.getMessage());

        verify(cartaRepository).findById(99L);
    }

    // ==================== CAMBIAR ESTADO ====================

    @Test
    void cambiarEstado_debeActualizarEstadoCorrectamente() {
        when(cartaRepository.findById(1L)).thenReturn(Optional.of(carta));
        when(cartaRepository.save(any(Carta.class))).thenAnswer(invocation -> {
            Carta c = invocation.getArgument(0);
            c.setEstado(EstadoCarta.APROBADA);
            return c;
        });

        CartaResponseDTO resultado = cartaService.cambiarEstado(1L, EstadoCarta.APROBADA);

        assertNotNull(resultado);
        assertEquals(EstadoCarta.APROBADA, resultado.getEstado());

        verify(cartaRepository).findById(1L);
        verify(cartaRepository).save(any(Carta.class));
    }

    // ==================== ELIMINAR ====================

    @Test
    void eliminar_debeEliminarCartaCorrectamente() {
        when(cartaRepository.existsById(1L)).thenReturn(true);
        doNothing().when(cartaRepository).deleteById(1L);

        cartaService.eliminar(1L);

        verify(cartaRepository).existsById(1L);
        verify(cartaRepository).deleteById(1L);
    }

    @Test
    void eliminar_debeLanzarExcepcionSiNoExiste() {
        when(cartaRepository.existsById(99L)).thenReturn(false);

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> cartaService.eliminar(99L)
        );

        assertEquals("Carta no encontrada con id: 99", exception.getMessage());

        verify(cartaRepository).existsById(99L);
    }

    // ==================== CASOS ESPECIALES ====================

    @Test
    void crear_conActividadOpcional_debeAsignarActividad() {
        when(apadrinadoRepository.findById(1L)).thenReturn(Optional.of(apadrinado));
        when(usuarioRepository.findById(1L)).thenReturn(Optional.of(usuario));
        when(expedienteRepository.findByApadrinadoId(1L)).thenReturn(Optional.of(expediente));
        when(actividadRepository.findById(1L)).thenReturn(Optional.of(new Actividad()));
        when(cartaRepository.save(any(Carta.class))).thenReturn(carta);

        CartaRequestDTO requestConActividad = CartaRequestDTO.builder()
                .titulo("Carta")
                .contenido("Contenido")
                .apadrinadoId(1L)
                .actividadId(1L)
                .build();

        CartaResponseDTO resultado = cartaService.crear(requestConActividad, 1L);

        assertNotNull(resultado);
        verify(actividadRepository).findById(1L);
    }

    @Test
    void crear_conTipoCartaNull_debeUsarTipoPorDefecto() {
        when(apadrinadoRepository.findById(1L)).thenReturn(Optional.of(apadrinado));
        when(usuarioRepository.findById(1L)).thenReturn(Optional.of(usuario));
        when(expedienteRepository.findByApadrinadoId(1L)).thenReturn(Optional.of(expediente));
        when(cartaRepository.save(any(Carta.class))).thenAnswer(invocation -> invocation.getArgument(0));

        CartaRequestDTO requestSinTipo = CartaRequestDTO.builder()
                .titulo("Carta")
                .contenido("Contenido")
                .apadrinadoId(1L)
                .tipoCarta(null)
                .build();

        CartaResponseDTO resultado = cartaService.crear(requestSinTipo, 1L);

        assertNotNull(resultado);
        assertEquals(TipoCarta.GENERAL, resultado.getTipoCarta());
    }
}
