package com.example.backend.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.example.backend.entity.Comunidad;
import com.example.backend.entity.Modulo;
import com.example.backend.repository.ActividadRepository;
import com.example.backend.repository.ComunidadRepository;
import com.example.backend.repository.ModuloRepository;

/**
 * Reglas de los módulos: Módulo 1 automático, elección obligatoria con
 * varios módulos, al menos un módulo y no eliminar módulos con actividades.
 */
@ExtendWith(MockitoExtension.class)
class ModuloServiceTest {

    @Mock
    private ModuloRepository moduloRepository;
    @Mock
    private ComunidadRepository comunidadRepository;
    @Mock
    private ActividadRepository actividadRepository;
    @Mock
    private SeguridadService seguridadService;
    @Mock
    private HistorialActividadService historialService;
    @Mock
    private ConvertidorDTO convertidor;

    @InjectMocks
    private ModuloService moduloService;

    private Comunidad comunidad;
    private Modulo modulo1;

    @BeforeEach
    void setUp() {
        comunidad = Comunidad.builder().id(1L).nombre("Chiantla").build();
        modulo1 = Modulo.builder().id(10L).comunidad(comunidad).nombre("Módulo 1").orden(1).build();
    }

    @Test
    void asegurarModuloInicial_creaModulo1SiNoExiste() {
        when(moduloRepository.findFirstByComunidadIdOrderByOrdenAscIdAsc(1L)).thenReturn(Optional.empty());
        when(moduloRepository.save(any(Modulo.class))).thenAnswer(i -> i.getArgument(0));

        Modulo creado = moduloService.asegurarModuloInicial(comunidad);

        assertEquals("Módulo 1", creado.getNombre());
        assertEquals(1, creado.getOrden());
        assertEquals(comunidad, creado.getComunidad());
    }

    @Test
    void resolverModulo_conUnSoloModuloUsaElModulo1() {
        when(moduloRepository.findFirstByComunidadIdOrderByOrdenAscIdAsc(1L)).thenReturn(Optional.of(modulo1));
        when(moduloRepository.countByComunidadId(1L)).thenReturn(1L);

        assertEquals(modulo1, moduloService.resolverModulo(comunidad, null));
    }

    @Test
    void resolverModulo_conVariosModulosExigeElegir() {
        when(moduloRepository.findFirstByComunidadIdOrderByOrdenAscIdAsc(1L)).thenReturn(Optional.of(modulo1));
        when(moduloRepository.countByComunidadId(1L)).thenReturn(2L);

        RuntimeException e = assertThrows(RuntimeException.class, () -> moduloService.resolverModulo(comunidad, null));
        assertTrue(e.getMessage().contains("seleccione el módulo"));
    }

    @Test
    void resolverModulo_rechazaModuloDeOtraComunidad() {
        Modulo ajeno = Modulo.builder().id(20L).nombre("Otro").comunidad(Comunidad.builder().id(2L).build()).build();
        when(moduloRepository.findFirstByComunidadIdOrderByOrdenAscIdAsc(1L)).thenReturn(Optional.of(modulo1));
        when(moduloRepository.findById(20L)).thenReturn(Optional.of(ajeno));

        assertThrows(RuntimeException.class, () -> moduloService.resolverModulo(comunidad, 20L));
    }

    @Test
    void eliminar_noPermiteQuitarElUnicoModulo() {
        when(moduloRepository.findById(10L)).thenReturn(Optional.of(modulo1));
        when(moduloRepository.countByComunidadId(1L)).thenReturn(1L);

        RuntimeException e = assertThrows(RuntimeException.class, () -> moduloService.eliminar(10L));
        assertTrue(e.getMessage().contains("al menos un módulo"));
        verify(moduloRepository, never()).delete(any());
    }

    @Test
    void eliminar_noPermiteModulosConActividades() {
        when(moduloRepository.findById(10L)).thenReturn(Optional.of(modulo1));
        when(moduloRepository.countByComunidadId(1L)).thenReturn(2L);
        when(actividadRepository.countByModuloId(10L)).thenReturn(3L);

        RuntimeException e = assertThrows(RuntimeException.class, () -> moduloService.eliminar(10L));
        assertTrue(e.getMessage().contains("Muévalas a otro módulo"));
        verify(moduloRepository, never()).delete(any());
    }
}
