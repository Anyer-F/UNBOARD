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

import com.example.backend.dto.ExpedienteResponseDTO;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.EstadoExpediente;
import com.example.backend.entity.Expediente;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.DocumentoRepository;
import com.example.backend.repository.ExpedienteRepository;

@ExtendWith(MockitoExtension.class)
class ExpedienteServiceTest {

    @Mock
    private ExpedienteRepository expedienteRepository;

    @Mock
    private ApadrinadoRepository apadrinadoRepository;

    @Mock
    private ApadrinadoService apadrinadoService;

    @Mock
    private DocumentoService documentoService;

    @Mock
    private ActividadService actividadService;

    @InjectMocks
    private ExpedienteService expedienteService;

    private Expediente expediente;
    private Apadrinado apadrinado;

    @BeforeEach
    void setUp() {
        apadrinado = Apadrinado.builder()
                .id(1L)
                .build();

        expediente = Expediente.builder()
                .id(1L)
                .codigo("EXP-2024-001")
                .estado(EstadoExpediente.ACTIVO)
                .fechaCreacion(LocalDate.now())
                .apadrinado(apadrinado)
                .build();
    }

    // ==================== LISTAR ====================

    @Test
    void listarTodos_debeRetornarListaDeExpedientes() {
        when(expedienteRepository.findAll()).thenReturn(List.of(expediente));

        List<ExpedienteResponseDTO> resultado = expedienteService.listarTodos();

        assertNotNull(resultado);
        assertEquals(1, resultado.size());
        assertEquals("EXP-2024-001", resultado.get(0).getCodigo());

        verify(expedienteRepository).findAll();
    }

    // ==================== OBTENER POR ID ====================

    @Test
    void obtenerPorId_debeRetornarExpedienteExistente() {
        when(expedienteRepository.findById(1L)).thenReturn(Optional.of(expediente));

        ExpedienteResponseDTO resultado = expedienteService.obtenerPorId(1L);

        assertNotNull(resultado);
        assertEquals(1L, resultado.getId());
        assertEquals("EXP-2024-001", resultado.getCodigo());

        verify(expedienteRepository).findById(1L);
    }

    @Test
    void obtenerPorId_debeLanzarExcepcionSiNoExiste() {
        when(expedienteRepository.findById(99L)).thenReturn(Optional.empty());

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> expedienteService.obtenerPorId(99L)
        );

        assertTrue(exception.getMessage().contains("Expediente no encontrado"));

        verify(expedienteRepository).findById(99L);
    }

    // ==================== OBTENER POR APADRINADO ====================

    @Test
    void obtenerPorApadrinadoId_debeRetornarExpediente() {
        when(expedienteRepository.findByApadrinadoId(1L)).thenReturn(Optional.of(expediente));

        ExpedienteResponseDTO resultado = expedienteService.obtenerPorApadrinadoId(1L);

        assertNotNull(resultado);
        assertEquals(1L, resultado.getId());

        verify(expedienteRepository).findByApadrinadoId(1L);
    }

    @Test
    void obtenerPorApadrinadoId_debeLanzarExcepcionSiNoExiste() {
        when(expedienteRepository.findByApadrinadoId(99L)).thenReturn(Optional.empty());

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> expedienteService.obtenerPorApadrinadoId(99L)
        );

        assertTrue(exception.getMessage().contains("Expediente no encontrado"));

        verify(expedienteRepository).findByApadrinadoId(99L);
    }

    // ==================== CREAR EXPEDIENTE ====================

    @Test
    void crearParaApadrinado_debeCrearExpedienteCorrectamente() {
        when(apadrinadoRepository.findById(1L)).thenReturn(Optional.of(apadrinado));
        when(expedienteRepository.save(any(Expediente.class))).thenReturn(expediente);

        ExpedienteResponseDTO resultado = expedienteService.crearParaApadrinado(1L);

        assertNotNull(resultado);
        assertEquals(1L, resultado.getId());

        verify(apadrinadoRepository).findById(1L);
        verify(expedienteRepository).save(any(Expediente.class));
    }

    @Test
    void crearParaApadrinado_debeLanzarExcepcionSiApadrinadoNoExiste() {
        when(apadrinadoRepository.findById(99L)).thenReturn(Optional.empty());

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> expedienteService.crearParaApadrinado(99L)
        );

        assertTrue(exception.getMessage().contains("Apadrinado no encontrado"));

        verify(apadrinadoRepository).findById(99L);
    }

    // ==================== CASOS ESPECIALES ====================

    @Test
    void listarTodos_debeRetornarListaVaciaSiNoHayExpedientes() {
        when(expedienteRepository.findAll()).thenReturn(List.of());

        List<ExpedienteResponseDTO> resultado = expedienteService.listarTodos();

        assertNotNull(resultado);
        assertTrue(resultado.isEmpty());

        verify(expedienteRepository).findAll();
    }

    @Test
    void obtenerPorId_debeRetornarTodosLosCampos() {
        when(expedienteRepository.findById(1L)).thenReturn(Optional.of(expediente));

        ExpedienteResponseDTO resultado = expedienteService.obtenerPorId(1L);

        assertNotNull(resultado);
        assertEquals(1L, resultado.getId());
        assertEquals("EXP-2024-001", resultado.getCodigo());
        assertEquals(EstadoExpediente.ACTIVO, resultado.getEstado());
        assertNotNull(resultado.getFechaCreacion());
    }
}
