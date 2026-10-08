package com.example.backend.service;

import java.util.Optional;

import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.config.JwtTokenProvider;
import com.example.backend.dto.LoginRequestDTO;
import com.example.backend.dto.LoginResponseDTO;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Coordinador;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.CoordinadorRepository;
import com.example.backend.repository.UsuarioRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@Slf4j
@RequiredArgsConstructor
public class AuthService {

    private final UsuarioRepository usuarioRepository;
    private final CoordinadorRepository coordinadorRepository;
    private final ApadrinadoRepository apadrinadoRepository;
    private final com.example.backend.repository.RolRepository rolRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;
    private final PasswordResetService passwordResetService;

    @Transactional
    public LoginResponseDTO registrar(com.example.backend.dto.UsuarioRequestDTO request) {
        if (request.getCorreo() == null || request.getCorreo().isBlank()) {
            throw new RuntimeException("El correo electrónico es obligatorio.");
        }
        if (usuarioRepository.existsByCorreo(request.getCorreo())) {
            throw new RuntimeException("Ya existe un usuario con el correo: " + request.getCorreo());
        }
        if (request.getPassword() == null || request.getPassword().isBlank()) {
            throw new RuntimeException("La contraseña es obligatoria.");
        }

        // FASE B: el registro público solo permite crear perfiles de apadrinado
        if (request.getRolId() != null) {
            com.example.backend.entity.Rol rolSolicitado = rolRepository.findById(request.getRolId()).orElse(null);
            if (rolSolicitado != null && !"APADRINADO".equalsIgnoreCase(rolSolicitado.getNombre())) {
                throw new RuntimeException(
                        "El registro público solo permite crear cuentas con rol de Apadrinado.");
            }
        }

        com.example.backend.entity.Rol rol = null;
        if (request.getRolId() != null) {
            rol = rolRepository.findById(request.getRolId()).orElse(null);
        }

        Usuario usuario = Usuario.builder()
                .nombre(request.getNombre())
                .correo(request.getCorreo())
                .password(passwordEncoder.encode(request.getPassword()))
                .rol(rol)
                .build();

        Usuario guardado = usuarioRepository.save(usuario);
        String rolNombre = guardado.getRol() != null ? guardado.getRol().getNombre() : "USUARIO";

        String token = jwtTokenProvider.generarToken(
                guardado.getCorreo(),
                guardado.getNombre(),
                rolNombre,
                guardado.getId(),
                null,
                null
        );

        return LoginResponseDTO.builder()
                .token(token)
                .tokenType("Bearer")
                .usuarioId(guardado.getId())
                .nombre(guardado.getNombre())
                .correo(guardado.getCorreo())
                .rol(rolNombre)
                .build();
    }

    @Transactional(readOnly = true)
    public LoginResponseDTO autenticar(LoginRequestDTO request) {
        Usuario usuario = usuarioRepository.findByCorreo(request.getCorreo())
                .orElseThrow(() -> new RuntimeException("Credenciales inválidas: correo no registrado."));

        if (!passwordEncoder.matches(request.getPassword(), usuario.getPassword())) {
            throw new RuntimeException("Credenciales inválidas: contraseña incorrecta.");
        }

        String rolNombre = usuario.getRol() != null ? usuario.getRol().getNombre() : "USUARIO";

        Long coordinadorId = null;
        Optional<Coordinador> coordinadorOpt = coordinadorRepository.findByUsuarioId(usuario.getId());
        if (coordinadorOpt.isPresent()) {
            coordinadorId = coordinadorOpt.get().getId();
        }

        Long apadrinadoId = null;
        Optional<Apadrinado> apadrinadoOpt = apadrinadoRepository.findByUsuarioId(usuario.getId());
        if (apadrinadoOpt.isPresent()) {
            apadrinadoId = apadrinadoOpt.get().getId();
        }

        String token = jwtTokenProvider.generarToken(
                usuario.getCorreo(),
                usuario.getNombre(),
                rolNombre,
                usuario.getId(),
                coordinadorId,
                apadrinadoId
        );

        return LoginResponseDTO.builder()
                .token(token)
                .tokenType("Bearer")
                .usuarioId(usuario.getId())
                .nombre(usuario.getNombre())
                .correo(usuario.getCorreo())
                .rol(rolNombre)
                .coordinadorId(coordinadorId)
                .apadrinadoId(apadrinadoId)
                .build();
    }

    @Transactional(readOnly = true)
    public LoginResponseDTO obtenerPerfil(String correo) {
        Usuario usuario = usuarioRepository.findByCorreo(correo)
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado con correo: " + correo));

        String rolNombre = usuario.getRol() != null ? usuario.getRol().getNombre() : "USUARIO";

        Long coordinadorId = null;
        Optional<Coordinador> coordinadorOpt = coordinadorRepository.findByUsuarioId(usuario.getId());
        if (coordinadorOpt.isPresent()) {
            coordinadorId = coordinadorOpt.get().getId();
        }

        Long apadrinadoId = null;
        Optional<Apadrinado> apadrinadoOpt = apadrinadoRepository.findByUsuarioId(usuario.getId());
        if (apadrinadoOpt.isPresent()) {
            apadrinadoId = apadrinadoOpt.get().getId();
        }

        return LoginResponseDTO.builder()
                .usuarioId(usuario.getId())
                .nombre(usuario.getNombre())
                .correo(usuario.getCorreo())
                .rol(rolNombre)
                .coordinadorId(coordinadorId)
                .apadrinadoId(apadrinadoId)
                .build();
    }

    // ==================== RECUPERACIÓN Y CAMBIO DE CONTRASEÑA ====================

    /**
     * Paso 1 del flujo de recuperación: genera un código para el correo indicado.
     * En este prototipo el código se registra en el log y se devuelve;
     * en producción se enviará por correo electrónico.
     */
    @Transactional(readOnly = true)
    public String solicitarRecuperacion(String correo) {
        if (correo == null || correo.isBlank()) {
            throw new RuntimeException("El correo electrónico es obligatorio.");
        }
        String correoNormalizado = correo.trim().toLowerCase();
        if (!usuarioRepository.existsByCorreo(correoNormalizado)) {
            // Se responde de forma genérica para no revelar correos registrados
            log.info("Solicitud de recuperación para correo no registrado: {}", correoNormalizado);
            return "";
        }
        return passwordResetService.generarCodigo(correoNormalizado);
    }

    /**
     * Paso 2 del flujo: verifica el código enviado al correo.
     */
    @Transactional(readOnly = true)
    public void verificarCodigo(String correo, String codigo) {
        if (correo == null || correo.isBlank()) {
            throw new RuntimeException("El correo electrónico es obligatorio.");
        }
        if (codigo == null || codigo.isBlank()) {
            throw new RuntimeException("El código de verificación es obligatorio.");
        }
        if (!passwordResetService.validarCodigo(correo.trim().toLowerCase(), codigo)) {
            throw new RuntimeException("Código de verificación inválido o expirado.");
        }
    }

    /**
     * Paso 3 del flujo: restablece la contraseña tras validar el código.
     */
    @Transactional
    public void restablecerPassword(String correo, String codigo, String nuevaPassword) {
        if (correo == null || correo.isBlank()) {
            throw new RuntimeException("El correo electrónico es obligatorio.");
        }
        if (codigo == null || codigo.isBlank()) {
            throw new RuntimeException("El código de verificación es obligatorio.");
        }
        if (nuevaPassword == null || nuevaPassword.length() < 6) {
            throw new RuntimeException("La nueva contraseña debe tener al menos 6 caracteres.");
        }

        String correoNormalizado = correo.trim().toLowerCase();
        if (!passwordResetService.validarCodigo(correoNormalizado, codigo)) {
            throw new RuntimeException("Código de verificación inválido o expirado.");
        }

        Usuario usuario = usuarioRepository.findByCorreo(correoNormalizado)
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado con correo: " + correoNormalizado));

        usuario.setPassword(passwordEncoder.encode(nuevaPassword));
        usuarioRepository.save(usuario);

        passwordResetService.invalidarCodigo(correoNormalizado);
        log.info("Contraseña restablecida correctamente para el usuario: {}", correoNormalizado);
    }

    /**
     * Cambio de contraseña con sesión iniciada: valida la contraseña actual.
     */
    @Transactional
    public void cambiarPassword(Authentication authentication, Long usuarioId,
            String passwordActual, String nuevaPassword) {
        if (authentication == null || !authentication.isAuthenticated()) {
            throw new RuntimeException("Debe iniciar sesión para cambiar la contraseña.");
        }
        if (passwordActual == null || passwordActual.isBlank()) {
            throw new RuntimeException("La contraseña actual es obligatoria.");
        }
        if (nuevaPassword == null || nuevaPassword.length() < 6) {
            throw new RuntimeException("La nueva contraseña debe tener al menos 6 caracteres.");
        }
        if (passwordActual.equals(nuevaPassword)) {
            throw new RuntimeException("La nueva contraseña debe ser diferente a la actual.");
        }

        Usuario usuario = usuarioRepository.findByCorreo(authentication.getName())
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado."));

        if (usuarioId != null && !usuarioId.equals(usuario.getId())) {
            throw new RuntimeException("No está autorizado para cambiar la contraseña de otro usuario.");
        }

        if (!passwordEncoder.matches(passwordActual, usuario.getPassword())) {
            throw new RuntimeException("La contraseña actual es incorrecta.");
        }

        usuario.setPassword(passwordEncoder.encode(nuevaPassword));
        usuarioRepository.save(usuario);
        log.info("Contraseña cambiada correctamente para el usuario: {}", usuario.getCorreo());
    }
}
