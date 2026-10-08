package com.example.backend.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

import com.example.backend.config.AccesoDenegadoException;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Comunidad;
import com.example.backend.entity.Coordinador;
import com.example.backend.entity.Rol;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ActividadRepository;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.CartaRepository;
import com.example.backend.repository.CoordinadorRepository;
import com.example.backend.repository.DocumentoRepository;
import com.example.backend.repository.ExpedienteRepository;
import com.example.backend.repository.MaterialApoyoRepository;
import com.example.backend.repository.UsuarioRepository;

/**
 * Tests de la Fase F: verificaciones de pertenencia con
 * múltiples comunidades por coordinador.
 */
@ExtendWith(MockitoExtension.class)
class SeguridadServiceTest {

    @Mock
    private UsuarioRepository usuarioRepository;

    @Mock
    private ApadrinadoRepository apadrinadoRepository;

    @Mock
    private CoordinadorRepository coordinadorRepository;

    @Mock
    private ActividadRepository actividadRepository;

    @Mock
    private CartaRepository cartaRepository;

    @Mock
    private DocumentoRepository documentoRepository;

    @Mock
    private ExpedienteRepository expedienteRepository;

    @Mock
    private MaterialApoyoRepository materialApoyoRepository;

    @InjectMocks
    private SeguridadService seguridadService;

    private static final String CORREO_CARLOS = "carlos.mendez@unbound.org";

    private Comunidad principal;
    private Comunidad segunda;

    @BeforeEach
    void setUp() {
        principal = Comunidad.builder().id(1L).nombre("Comunidad Principal").build();
        segunda = Comunidad.builder().id(2L).nombre("Segunda Comunidad").build();

        Rol rolCoordinador = Rol.builder().id(2L).nombre("Coordinador").build();
        Usuario carlos = Usuario.builder()
                .id(1L)
                .nombre("Carlos Méndez")
                .correo(CORREO_CARLOS)
                .rol(rolCoordinador)
                .build();

        Coordinador coordinadorCarlos = Coordinador.builder()
                .id(10L)
                .usuario(carlos)
                .comunidad(principal)
                .comunidades(new ArrayList<>(List.of(segunda)))
                .build();

        Authentication auth = mock(Authentication.class);
        when(auth.isAuthenticated()).thenReturn(true);
        when(auth.getName()).thenReturn(CORREO_CARLOS);
        SecurityContextHolder.getContext().setAuthentication(auth);

        when(usuarioRepository.findByCorreo(CORREO_CARLOS)).thenReturn(Optional.of(carlos));
        when(coordinadorRepository.findByUsuarioId(1L)).thenReturn(Optional.of(coordinadorCarlos));
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void comunidadesDelCoordinador_incluyePrincipalYAsociadas() {
        Set<Long> ids = seguridadService.comunidadesDelCoordinador();
        assertEquals(new LinkedHashSet<>(List.of(1L, 2L)), ids);
    }

    @Test
    void verificarComunidadPropia_comunidadPrincipalEsPermitida() {
        assertDoesNotThrow(() -> seguridadService.verificarComunidadPropia(1L));
    }

    @Test
    void verificarComunidadPropia_comunidadAsociadaEsPermitida() {
        assertDoesNotThrow(() -> seguridadService.verificarComunidadPropia(2L));
    }

    @Test
    void verificarComunidadPropia_comunidadAjenaEsDenegada() {
        assertThrows(AccesoDenegadoException.class,
                () -> seguridadService.verificarComunidadPropia(3L));
    }

    @Test
    void verificarComunidadAccesible_comunidadAsociadaEsPermitida() {
        assertDoesNotThrow(() -> seguridadService.verificarComunidadAccesible(2L));
    }

    @Test
    void verificarComunidadAccesible_comunidadAjenaEsDenegada() {
        assertThrows(AccesoDenegadoException.class,
                () -> seguridadService.verificarComunidadAccesible(3L));
    }

    @Test
    void verificarApadrinadoAccesible_apadrinadoDeComunidadAsociadaEsAccesible() {
        Apadrinado apadrinado = Apadrinado.builder()
                .id(100L)
                .usuario(Usuario.builder().id(50L)
                        .rol(Rol.builder().id(3L).nombre("Apadrinado").build())
                        .build())
                .comunidad(segunda)
                .build();
        when(apadrinadoRepository.findById(100L)).thenReturn(Optional.of(apadrinado));

        assertDoesNotThrow(() -> seguridadService.verificarApadrinadoAccesible(100L));
    }

    @Test
    void verificarApadrinadoAccesible_apadrinadoDeComunidadAjenaEsDenegado() {
        Comunidad ajena = Comunidad.builder().id(3L).nombre("Ajena").build();
        Apadrinado apadrinado = Apadrinado.builder()
                .id(100L)
                .usuario(Usuario.builder().id(50L)
                        .rol(Rol.builder().id(3L).nombre("Apadrinado").build())
                        .build())
                .comunidad(ajena)
                .build();
        when(apadrinadoRepository.findById(100L)).thenReturn(Optional.of(apadrinado));

        assertThrows(AccesoDenegadoException.class,
                () -> seguridadService.verificarApadrinadoAccesible(100L));
    }

    @Test
    void verificarApadrinadoAccesible_responsabilidadDirectaSigueAccesible() {
        Coordinador coordinadorCarlos = coordinadorRepository.findByUsuarioId(1L).orElseThrow();
        Apadrinado apadrinado = Apadrinado.builder()
                .id(100L)
                .usuario(Usuario.builder().id(50L)
                        .rol(Rol.builder().id(3L).nombre("Apadrinado").build())
                        .build())
                .coordinador(coordinadorCarlos)
                .build();
        when(apadrinadoRepository.findById(100L)).thenReturn(Optional.of(apadrinado));

        assertDoesNotThrow(() -> seguridadService.verificarApadrinadoAccesible(100L));
    }
}
