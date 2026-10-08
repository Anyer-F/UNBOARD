package com.example.backend.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.example.backend.config.JwtTokenProvider;
import com.example.backend.dto.LoginRequestDTO;
import com.example.backend.dto.LoginResponseDTO;
import com.example.backend.dto.UsuarioRequestDTO;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Coordinador;
import com.example.backend.entity.Rol;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.CoordinadorRepository;
import com.example.backend.repository.RolRepository;
import com.example.backend.repository.UsuarioRepository;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private UsuarioRepository usuarioRepository;

    @Mock
    private CoordinadorRepository coordinadorRepository;

    @Mock
    private ApadrinadoRepository apadrinadoRepository;

    @Mock
    private RolRepository rolRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtTokenProvider jwtTokenProvider;

    @InjectMocks
    private AuthService authService;

    private Usuario usuario;
    private Rol rol;

    @BeforeEach
    void setUp() {
        rol = Rol.builder()
                .id(1L)
                .nombre("APADRINADO")
                .build();

        usuario = Usuario.builder()
                .id(1L)
                .nombre("Carlos")
                .correo("carlos@example.com")
                .password("password123")
                .rol(rol)
                .build();
    }

    // ==================== REGISTRAR ====================

    @Test
    void registrar_debeCrearUsuarioCorrectamente() {
        UsuarioRequestDTO request = new UsuarioRequestDTO();
        request.setNombre("Nuevo Usuario");
        request.setCorreo("nuevo@example.com");
        request.setPassword("password123");
        request.setRolId(1L);

        when(usuarioRepository.existsByCorreo("nuevo@example.com")).thenReturn(false);
        when(rolRepository.findById(1L)).thenReturn(Optional.of(rol));
        when(passwordEncoder.encode("password123")).thenReturn("encoded_password");
        when(usuarioRepository.save(any(Usuario.class))).thenReturn(usuario);
        when(jwtTokenProvider.generarToken(anyString(), anyString(), anyString(), anyLong(), isNull(), isNull()))
                .thenReturn("jwt-token-test");

        LoginResponseDTO resultado = authService.registrar(request);

        assertNotNull(resultado);
        assertEquals("jwt-token-test", resultado.getToken());
        assertEquals("Bearer", resultado.getTokenType());
        assertEquals(1L, resultado.getUsuarioId());

        verify(usuarioRepository).existsByCorreo("nuevo@example.com");
        verify(usuarioRepository).save(any(Usuario.class));
    }

    @Test
    void registrar_debeLanzarExcepcionSiCorreoEstaVacio() {
        UsuarioRequestDTO request = new UsuarioRequestDTO();
        request.setCorreo("");
        request.setPassword("password123");

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> authService.registrar(request)
        );

        assertEquals("El correo electrónico es obligatorio.", exception.getMessage());
    }

    @Test
    void registrar_debeLanzarExcepcionSiCorreoYaExiste() {
        UsuarioRequestDTO request = new UsuarioRequestDTO();
        request.setCorreo("carlos@example.com");
        request.setPassword("password123");

        when(usuarioRepository.existsByCorreo("carlos@example.com")).thenReturn(true);

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> authService.registrar(request)
        );

        assertTrue(exception.getMessage().contains("Ya existe un usuario"));

        verify(usuarioRepository).existsByCorreo("carlos@example.com");
    }

    @Test
    void registrar_debeLanzarExcepcionSiPasswordEstaVacio() {
        UsuarioRequestDTO request = new UsuarioRequestDTO();
        request.setCorreo("nuevo@example.com");
        request.setPassword("");

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> authService.registrar(request)
        );

        assertEquals("La contraseña es obligatoria.", exception.getMessage());
    }

    @Test
    void registrar_debeFuncionarSinRol() {
        UsuarioRequestDTO request = new UsuarioRequestDTO();
        request.setNombre("Usuario Sin Rol");
        request.setCorreo("sinrol@example.com");
        request.setPassword("password123");
        request.setRolId(null);

        when(usuarioRepository.existsByCorreo("sinrol@example.com")).thenReturn(false);
        when(passwordEncoder.encode("password123")).thenReturn("encoded_password");
        when(usuarioRepository.save(any(Usuario.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(jwtTokenProvider.generarToken(anyString(), anyString(), anyString(), any(), isNull(), isNull()))
                .thenReturn("jwt-token-test");

        LoginResponseDTO resultado = authService.registrar(request);

        assertNotNull(resultado);
        assertEquals("USUARIO", resultado.getRol());
    }

    // ==================== AUTENTICAR ====================

    @Test
    void autenticar_debeRetornarTokenYUsuario() {
        LoginRequestDTO request = new LoginRequestDTO();
        request.setCorreo("carlos@example.com");
        request.setPassword("password123");

        when(usuarioRepository.findByCorreo("carlos@example.com")).thenReturn(Optional.of(usuario));
        when(passwordEncoder.matches("password123", "password123")).thenReturn(true);
        when(coordinadorRepository.findByUsuarioId(1L)).thenReturn(Optional.empty());
        when(apadrinadoRepository.findByUsuarioId(1L)).thenReturn(Optional.empty());
        when(jwtTokenProvider.generarToken(anyString(), anyString(), anyString(), anyLong(), isNull(), isNull()))
                .thenReturn("jwt-token-test");

        LoginResponseDTO resultado = authService.autenticar(request);

        assertNotNull(resultado);
        assertEquals("jwt-token-test", resultado.getToken());
        assertEquals("Bearer", resultado.getTokenType());
        assertEquals(1L, resultado.getUsuarioId());
        assertEquals("Carlos", resultado.getNombre());
        assertEquals("carlos@example.com", resultado.getCorreo());
        assertEquals("APADRINADO", resultado.getRol());

        verify(usuarioRepository).findByCorreo("carlos@example.com");
    }

    @Test
    void autenticar_debeLanzarExcepcionSiCorreoNoExiste() {
        LoginRequestDTO request = new LoginRequestDTO();
        request.setCorreo("noexiste@example.com");
        request.setPassword("password123");

        when(usuarioRepository.findByCorreo("noexiste@example.com")).thenReturn(Optional.empty());

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> authService.autenticar(request)
        );

        assertTrue(exception.getMessage().contains("Credenciales inválidas"));

        verify(usuarioRepository).findByCorreo("noexiste@example.com");
    }

    @Test
    void autenticar_debeLanzarExcepcionSiPasswordEsIncorrecta() {
        LoginRequestDTO request = new LoginRequestDTO();
        request.setCorreo("carlos@example.com");
        request.setPassword("wrong_password");

        when(usuarioRepository.findByCorreo("carlos@example.com")).thenReturn(Optional.of(usuario));
        when(passwordEncoder.matches("wrong_password", "password123")).thenReturn(false);

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> authService.autenticar(request)
        );

        assertTrue(exception.getMessage().contains("Credenciales inválidas"));
    }

    @Test
    void autenticar_conCoordinador_debeRetornarCoordinadorId() {
        Coordinador coordinador = Coordinador.builder().id(1L).build();

        LoginRequestDTO request = new LoginRequestDTO();
        request.setCorreo("carlos@example.com");
        request.setPassword("password123");

        when(usuarioRepository.findByCorreo("carlos@example.com")).thenReturn(Optional.of(usuario));
        when(passwordEncoder.matches("password123", "password123")).thenReturn(true);
        when(coordinadorRepository.findByUsuarioId(1L)).thenReturn(Optional.of(coordinador));
        when(apadrinadoRepository.findByUsuarioId(1L)).thenReturn(Optional.empty());
        when(jwtTokenProvider.generarToken(anyString(), anyString(), anyString(), anyLong(), anyLong(), isNull()))
                .thenReturn("jwt-token-test");

        LoginResponseDTO resultado = authService.autenticar(request);

        assertNotNull(resultado);
        assertEquals(1L, resultado.getCoordinadorId());
        assertNull(resultado.getApadrinadoId());
    }

    @Test
    void autenticar_conApadrinado_debeRetornarApadrinadoId() {
        Apadrinado apadrinado = Apadrinado.builder().id(1L).build();

        LoginRequestDTO request = new LoginRequestDTO();
        request.setCorreo("carlos@example.com");
        request.setPassword("password123");

        when(usuarioRepository.findByCorreo("carlos@example.com")).thenReturn(Optional.of(usuario));
        when(passwordEncoder.matches("password123", "password123")).thenReturn(true);
        when(coordinadorRepository.findByUsuarioId(1L)).thenReturn(Optional.empty());
        when(apadrinadoRepository.findByUsuarioId(1L)).thenReturn(Optional.of(apadrinado));
        when(jwtTokenProvider.generarToken(anyString(), anyString(), anyString(), anyLong(), isNull(), anyLong()))
                .thenReturn("jwt-token-test");

        LoginResponseDTO resultado = authService.autenticar(request);

        assertNotNull(resultado);
        assertEquals(1L, resultado.getApadrinadoId());
        assertNull(resultado.getCoordinadorId());
    }

    // ==================== OBTENER PERFIL ====================

    @Test
    void obtenerPerfil_debeRetornarDatosDelUsuario() {
        when(usuarioRepository.findByCorreo("carlos@example.com")).thenReturn(Optional.of(usuario));
        when(coordinadorRepository.findByUsuarioId(1L)).thenReturn(Optional.empty());
        when(apadrinadoRepository.findByUsuarioId(1L)).thenReturn(Optional.empty());

        LoginResponseDTO resultado = authService.obtenerPerfil("carlos@example.com");

        assertNotNull(resultado);
        assertEquals(1L, resultado.getUsuarioId());
        assertEquals("Carlos", resultado.getNombre());
        assertEquals("carlos@example.com", resultado.getCorreo());
        assertEquals("APADRINADO", resultado.getRol());

        verify(usuarioRepository).findByCorreo("carlos@example.com");
    }

    @Test
    void obtenerPerfil_debeLanzarExcepcionSiUsuarioNoExiste() {
        when(usuarioRepository.findByCorreo("noexiste@example.com")).thenReturn(Optional.empty());

        RuntimeException exception = assertThrows(
                RuntimeException.class,
                () -> authService.obtenerPerfil("noexiste@example.com")
        );

        assertTrue(exception.getMessage().contains("Usuario no encontrado"));

        verify(usuarioRepository).findByCorreo("noexiste@example.com");
    }

    @Test
    void obtenerPerfil_conCoordinadorYApadrinado_debeRetornarAmbosIds() {
        Coordinador coordinador = Coordinador.builder().id(2L).build();
        Apadrinado apadrinado = Apadrinado.builder().id(3L).build();

        when(usuarioRepository.findByCorreo("carlos@example.com")).thenReturn(Optional.of(usuario));
        when(coordinadorRepository.findByUsuarioId(1L)).thenReturn(Optional.of(coordinador));
        when(apadrinadoRepository.findByUsuarioId(1L)).thenReturn(Optional.of(apadrinado));

        LoginResponseDTO resultado = authService.obtenerPerfil("carlos@example.com");

        assertNotNull(resultado);
        assertEquals(2L, resultado.getCoordinadorId());
        assertEquals(3L, resultado.getApadrinadoId());
    }

    @Test
    void obtenerPerfil_sinRol_debeRetornarRolPorDefecto() {
        Usuario usuarioSinRol = Usuario.builder()
                .id(2L)
                .nombre("Sin Rol")
                .correo("sinrol@example.com")
                .password("password123")
                .rol(null)
                .build();

        when(usuarioRepository.findByCorreo("sinrol@example.com")).thenReturn(Optional.of(usuarioSinRol));
        when(coordinadorRepository.findByUsuarioId(2L)).thenReturn(Optional.empty());
        when(apadrinadoRepository.findByUsuarioId(2L)).thenReturn(Optional.empty());

        LoginResponseDTO resultado = authService.obtenerPerfil("sinrol@example.com");

        assertNotNull(resultado);
        assertEquals("USUARIO", resultado.getRol());
    }
}
