package com.example.backend.config;

import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Comunidad;
import com.example.backend.entity.Coordinador;
import com.example.backend.entity.Rol;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.CodigoAccesoRepository;
import com.example.backend.repository.ComunidadRepository;
import com.example.backend.repository.CoordinadorRepository;
import com.example.backend.repository.RolRepository;
import com.example.backend.repository.UsuarioRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Component
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements CommandLineRunner {

    private final RolRepository rolRepository;
    private final ComunidadRepository comunidadRepository;
    private final UsuarioRepository usuarioRepository;
    private final CoordinadorRepository coordinadorRepository;
    private final ApadrinadoRepository apadrinadoRepository;
    private final CodigoAccesoRepository codigoAccesoRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) {
        log.info("Inicializando datos base del sistema UNBOUND...");

        // 1. Roles
        Rol rolAdmin = obtenerOCrearRol("Administrador");
        Rol rolCoord = obtenerOCrearRol("Coordinador");
        Rol rolApad = obtenerOCrearRol("Apadrinado");

        // 2. Comunidades de Huehuetenango
        Comunidad chiantla = obtenerOCrearComunidad("Chiantla", "Chiantla", "Huehuetenango");
        Comunidad barillas = obtenerOCrearComunidad("Santa Cruz Barillas", "Barillas", "Huehuetenango");
        Comunidad sanPedro = obtenerOCrearComunidad("San Pedro Necta", "San Pedro Necta", "Huehuetenango");
        Comunidad aguacatan = obtenerOCrearComunidad("Aguacatán", "Aguacatán", "Huehuetenango");

        // 3. Migrar a BCrypt cualquier contraseña almacenada en texto plano
        migrarContrasenasTextoPlano();

        // 4. Asegurar usuario Administrador
        if (!usuarioRepository.existsByCorreo("admin@unbound.org")) {
            Usuario admin = Usuario.builder()
                    .nombre("Administrador UNBOUND")
                    .correo("admin@unbound.org")
                    .password(passwordEncoder.encode("admin123"))
                    .rol(rolAdmin)
                    .build();
            usuarioRepository.save(admin);
            log.info("Usuario Administrador creado: admin@unbound.org / admin123");
        }

        // 5. Vincular comunidad por defecto a coordinadores sin comunidad
        coordinadorRepository.findAll().forEach(coord -> {
            if (coord.getComunidad() == null) {
                coord.setComunidad(chiantla);
                coordinadorRepository.save(coord);
                log.info("Coordinador ID {} vinculado a comunidad Chiantla", coord.getId());
            }
        });

        // 6. Vincular comunidad por defecto a apadrinados sin comunidad
        apadrinadoRepository.findAll().forEach(apad -> {
            if (apad.getComunidad() == null) {
                apad.setComunidad(chiantla);
                apadrinadoRepository.save(apad);
                log.info("Apadrinado ID {} vinculado a comunidad Chiantla", apad.getId());
            }
        });

        // 7. Código de acceso de prueba para la comunidad del coordinador Carlos
        if (codigoAccesoRepository.findByCodigo("CHIANTLA-26").isEmpty()) {
            usuarioRepository.findByCorreo("carlos.mendez@unbound.org").ifPresent(u -> {
                coordinadorRepository.findByUsuarioId(u.getId()).ifPresent(coord -> {
                    if (coord.getComunidad() != null) {
                        codigoAccesoRepository.save(
                                com.example.backend.entity.CodigoAcceso.builder()
                                        .codigo("CHIANTLA-26")
                                        .comunidad(coord.getComunidad())
                                        .coordinador(coord)
                                        .activo(true)
                                        .fechaCreacion(java.time.LocalDateTime.now())
                                        .fechaExpiracion(java.time.LocalDateTime.now().plusMonths(6))
                                        .maxUsos(50)
                                        .usos(0)
                                        .descripcion("Código de acceso de prueba")
                                        .build());
                        log.info("Código de acceso de prueba creado: CHIANTLA-26 (comunidad ID {})",
                                coord.getComunidad().getId());
                    }
                });
            });
        }

        log.info("Inicialización de datos base finalizada con éxito.");
    }

    /**
     * Migra a BCrypt todas las contraseñas que no estén codificadas.
     */
    private void migrarContrasenasTextoPlano() {
        usuarioRepository.findAll().forEach(u -> {
            if (u.getPassword() == null || !u.getPassword().startsWith("$2a$")) {
                String plana = (u.getPassword() != null && !u.getPassword().isBlank())
                        ? u.getPassword()
                        : "password123";
                u.setPassword(passwordEncoder.encode(plana));
                usuarioRepository.save(u);
                log.info("Contraseña migrada a BCrypt para el usuario: {}", u.getCorreo());
            }
        });
    }

    private Rol obtenerOCrearRol(String nombre) {
        return rolRepository.findByNombre(nombre)
                .orElseGet(() -> {
                    Rol rol = new Rol();
                    rol.setNombre(nombre);
                    return rolRepository.save(rol);
                });
    }

    private Comunidad obtenerOCrearComunidad(String nombre, String municipio, String departamento) {
        return comunidadRepository.findAll().stream()
                .filter(c -> c.getNombre() != null && c.getNombre().equalsIgnoreCase(nombre))
                .findFirst()
                .orElseGet(() -> {
                    Comunidad c = Comunidad.builder()
                            .nombre(nombre)
                            .municipio(municipio)
                            .departamento(departamento)
                            .build();
                    return comunidadRepository.save(c);
                });
    }
}
