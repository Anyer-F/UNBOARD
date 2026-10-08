package com.example.backend.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.example.backend.config.AccesoDenegadoException;
import com.example.backend.dto.ComunidadResponseDTO;
import com.example.backend.entity.Comunidad;
import com.example.backend.entity.Coordinador;
import com.example.backend.repository.ComunidadRepository;
import com.example.backend.repository.CoordinadorRepository;
import com.example.backend.repository.UsuarioRepository;

/**
 * Tests de la Fase F: múltiples comunidades por coordinador.
 */
@ExtendWith(MockitoExtension.class)
class CoordinadorServiceTest {

    @Mock
    private CoordinadorRepository coordinadorRepository;

    @Mock
    private UsuarioRepository usuarioRepository;

    @Mock
    private ComunidadRepository comunidadRepository;

    @InjectMocks
    private CoordinadorService coordinadorService;

    private Coordinador coordinador;
    private Comunidad principal;
    private Comunidad segunda;

    @BeforeEach
    void setUp() {
        principal = Comunidad.builder().id(1L).nombre("Comunidad Principal").build();
        segunda = Comunidad.builder().id(2L).nombre("Segunda Comunidad").build();
        coordinador = Coordinador.builder()
                .id(10L)
                .comunidad(principal)
                .comunidades(new ArrayList<>())
                .build();
    }

    @Test
    void asociarComunidad_nuevaLaAgregaALasResponsabilidades() {
        when(coordinadorRepository.findById(10L)).thenReturn(Optional.of(coordinador));
        when(comunidadRepository.findById(2L)).thenReturn(Optional.of(segunda));
        when(coordinadorRepository.findByComunidadId(2L)).thenReturn(List.of());
        when(coordinadorRepository.findByComunidadAsociadaId(2L)).thenReturn(List.of());
        when(coordinadorRepository.save(any(Coordinador.class))).thenReturn(coordinador);

        List<ComunidadResponseDTO> resultado = coordinadorService.asociarComunidad(10L, 2L);

        assertEquals(2, resultado.size());
        assertTrue(coordinador.getComunidades().stream()
                .anyMatch(c -> c.getId().equals(2L)));
        verify(coordinadorRepository).save(coordinador);
    }

    @Test
    void asociarComunidad_idempotenteNoDuplica() {
        coordinador.getComunidades().add(segunda);
        when(coordinadorRepository.findById(10L)).thenReturn(Optional.of(coordinador));
        when(comunidadRepository.findById(2L)).thenReturn(Optional.of(segunda));

        List<ComunidadResponseDTO> resultado = coordinadorService.asociarComunidad(10L, 2L);

        assertEquals(2, resultado.size());
        assertEquals(1, coordinador.getComunidades().size());
        verify(coordinadorRepository, never()).save(any(Coordinador.class));
    }

    @Test
    void asociarComunidad_principalIdempotente() {
        when(coordinadorRepository.findById(10L)).thenReturn(Optional.of(coordinador));
        when(comunidadRepository.findById(1L)).thenReturn(Optional.of(principal));

        List<ComunidadResponseDTO> resultado = coordinadorService.asociarComunidad(10L, 1L);

        assertEquals(1, resultado.size());
        assertTrue(coordinador.getComunidades().isEmpty());
        verify(coordinadorRepository, never()).save(any(Coordinador.class));
    }

    @Test
    void asociarComunidad_comunidadPrincipalDeOtroCoordinadorDeniega() {
        Coordinador otro = Coordinador.builder()
                .id(20L)
                .comunidad(segunda)
                .comunidades(new ArrayList<>())
                .build();
        when(coordinadorRepository.findById(10L)).thenReturn(Optional.of(coordinador));
        when(comunidadRepository.findById(2L)).thenReturn(Optional.of(segunda));
        when(coordinadorRepository.findByComunidadId(2L)).thenReturn(List.of(otro));

        assertThrows(AccesoDenegadoException.class,
                () -> coordinadorService.asociarComunidad(10L, 2L));
    }

    @Test
    void asociarComunidad_comunidadAsociadaDeOtroCoordinadorDeniega() {
        Coordinador otro = Coordinador.builder()
                .id(20L)
                .comunidad(principal)
                .comunidades(new ArrayList<>(List.of(segunda)))
                .build();
        when(coordinadorRepository.findById(10L)).thenReturn(Optional.of(coordinador));
        when(comunidadRepository.findById(2L)).thenReturn(Optional.of(segunda));
        when(coordinadorRepository.findByComunidadId(2L)).thenReturn(List.of());
        when(coordinadorRepository.findByComunidadAsociadaId(2L)).thenReturn(List.of(otro));

        assertThrows(AccesoDenegadoException.class,
                () -> coordinadorService.asociarComunidad(10L, 2L));
    }

    @Test
    void desasociarComunidad_laEliminaDeSusResponsabilidades() {
        coordinador.getComunidades().add(segunda);
        when(coordinadorRepository.findById(10L)).thenReturn(Optional.of(coordinador));
        when(coordinadorRepository.save(any(Coordinador.class))).thenReturn(coordinador);

        List<ComunidadResponseDTO> resultado = coordinadorService.desasociarComunidad(10L, 2L);

        assertEquals(1, resultado.size());
        assertTrue(coordinador.getComunidades().isEmpty());
        verify(coordinadorRepository).save(coordinador);
    }

    @Test
    void desasociarComunidad_principalNoSePuedeDesasociar() {
        when(coordinadorRepository.findById(10L)).thenReturn(Optional.of(coordinador));

        assertThrows(AccesoDenegadoException.class,
                () -> coordinadorService.desasociarComunidad(10L, 1L));
    }

    @Test
    void listarComunidadesDelCoordinador_incluyePrincipalYAsociadas() {
        coordinador.getComunidades().add(segunda);
        when(coordinadorRepository.findById(10L)).thenReturn(Optional.of(coordinador));

        List<ComunidadResponseDTO> resultado =
                coordinadorService.listarComunidadesDelCoordinador(10L);

        assertEquals(2, resultado.size());
        assertEquals(1L, resultado.get(0).getId());
        assertEquals(2L, resultado.get(1).getId());
    }
}
