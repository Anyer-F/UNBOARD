package com.example.backend.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.backend.dto.CartaRequestDTO;
import com.example.backend.dto.CartaResponseDTO;
import com.example.backend.dto.PagedResponseDTO;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Carta.EstadoCarta;
import com.example.backend.entity.Coordinador;
import com.example.backend.service.CartaService;
import com.example.backend.service.SeguridadService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/cartas")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class CartaController {

    private final CartaService cartaService;
    private final SeguridadService seguridadService;

    @GetMapping
    public ResponseEntity<List<CartaResponseDTO>> listarTodas() {
        // FASE B: el coordinador ve las cartas de sus apadrinados; el apadrinado solo las suyas
        Coordinador coordinador = seguridadService.coordinadorActual();
        if (coordinador != null) {
            return ResponseEntity.ok(cartaService.listarPorCoordinador(coordinador.getId()));
        }
        Apadrinado apadrinado = seguridadService.apadrinadoActual();
        if (apadrinado != null) {
            return ResponseEntity.ok(cartaService.listarPorApadrinado(apadrinado.getId()));
        }
        throw new com.example.backend.config.AccesoDenegadoException("Acceso denegado.");
    }

    @GetMapping("/{id}")
    public ResponseEntity<CartaResponseDTO> obtenerPorId(@PathVariable Long id) {
        seguridadService.verificarCarteraAccesible(id);
        return ResponseEntity.ok(cartaService.obtenerPorId(id));
    }

    @GetMapping("/apadrinado/{apadrinadoId}")
    public ResponseEntity<List<CartaResponseDTO>> listarPorApadrinado(@PathVariable Long apadrinadoId) {
        seguridadService.verificarApadrinadoAccesible(apadrinadoId);
        return ResponseEntity.ok(cartaService.listarPorApadrinado(apadrinadoId));
    }

    @GetMapping("/expediente/{expedienteId}")
    public ResponseEntity<List<CartaResponseDTO>> listarPorExpediente(@PathVariable Long expedienteId) {
        seguridadService.verificarExpedienteAccesible(expedienteId);
        return ResponseEntity.ok(cartaService.listarPorExpediente(expedienteId));
    }

    @GetMapping("/actividad/{actividadId}")
    public ResponseEntity<List<CartaResponseDTO>> listarPorActividad(@PathVariable Long actividadId) {
        seguridadService.verificarActividadAccesible(actividadId);
        return ResponseEntity.ok(cartaService.listarPorActividad(actividadId));
    }

    @GetMapping("/estado/{estado}")
    public ResponseEntity<List<CartaResponseDTO>> listarPorEstado(@PathVariable EstadoCarta estado) {
        // FASE B: filtrado por pertenencia
        Coordinador coordinador = seguridadService.coordinadorActual();
        if (coordinador != null) {
            return ResponseEntity.ok(cartaService.listarPorCoordinadorYEstado(coordinador.getId(), estado));
        }
        Apadrinado apadrinado = seguridadService.apadrinadoActual();
        if (apadrinado != null) {
            return ResponseEntity.ok(cartaService.listarPorApadrinadoYEstado(apadrinado.getId(), estado));
        }
        throw new com.example.backend.config.AccesoDenegadoException("Acceso denegado.");
    }

    @GetMapping("/apadrinado/{apadrinadoId}/estado/{estado}")
    public ResponseEntity<List<CartaResponseDTO>> listarPorApadrinadoYEstado(
            @PathVariable Long apadrinadoId,
            @PathVariable EstadoCarta estado) {
        seguridadService.verificarApadrinadoAccesible(apadrinadoId);
        return ResponseEntity.ok(cartaService.listarPorApadrinadoYEstado(apadrinadoId, estado));
    }

    @PostMapping
    public ResponseEntity<CartaResponseDTO> crear(@RequestBody CartaRequestDTO request) {
        // FASE B: solo el apadrinado (para sí mismo) o el coordinador
        // (para un apadrinado bajo su responsabilidad) puede crear cartas
        Apadrinado apadrinado = seguridadService.apadrinadoActual();
        if (apadrinado != null) {
            if (request.getApadrinadoId() == null
                    || !request.getApadrinadoId().equals(apadrinado.getId())) {
                throw new com.example.backend.config.AccesoDenegadoException(
                        "Solo puede crear cartas para su propio expediente.");
            }
        } else {
            seguridadService.requerirCoordinador();
            seguridadService.verificarApadrinadoAccesible(request.getApadrinadoId());
        }

        Long usuarioId = seguridadService.usuarioActual().getId();
        CartaResponseDTO nueva = cartaService.crear(request, usuarioId);
        return ResponseEntity.status(HttpStatus.CREATED).body(nueva);
    }

    @PutMapping("/{id}")
    public ResponseEntity<CartaResponseDTO> actualizar(@PathVariable Long id, @RequestBody CartaRequestDTO request) {
        seguridadService.verificarCarteraAccesible(id);
        return ResponseEntity.ok(cartaService.actualizar(id, request));
    }

    @PatchMapping("/{id}/enviar")
    public ResponseEntity<CartaResponseDTO> enviarCarta(@PathVariable Long id) {
        seguridadService.verificarCarteraAccesible(id);
        return ResponseEntity.ok(cartaService.enviarCarta(id));
    }

    @PatchMapping("/{id}/estado")
    public ResponseEntity<CartaResponseDTO> cambiarEstado(
            @PathVariable Long id,
            @RequestParam EstadoCarta estado) {
        // FASE B: aprobar/rechazar cartas es función del coordinador responsable
        seguridadService.requerirCoordinador();
        seguridadService.verificarCarteraAccesible(id);
        return ResponseEntity.ok(cartaService.cambiarEstado(id, estado));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        seguridadService.verificarCarteraAccesible(id);
        cartaService.eliminar(id);
        return ResponseEntity.noContent().build();
    }

    // ==================== ENDPOINTS PAGINADOS ====================

    @GetMapping("/paginado")
    public ResponseEntity<PagedResponseDTO<CartaResponseDTO>> listarTodasPaginado(
            @RequestParam(defaultValue = "0") int pagina,
            @RequestParam(defaultValue = "10") int tamano,
            @RequestParam(defaultValue = "fechaCreacion") String sortBy,
            @RequestParam(defaultValue = "desc") String sortDir) {
        Coordinador coordinador = seguridadService.coordinadorActual();
        if (coordinador != null) {
            return ResponseEntity.ok(cartaService.listarPorCoordinadorPaginado(
                    coordinador.getId(), null, null, pagina, tamano, sortBy, sortDir));
        }
        Apadrinado apadrinado = seguridadService.apadrinadoActual();
        if (apadrinado != null) {
            return ResponseEntity.ok(cartaService.listarPorApadrinadoPaginado(
                    apadrinado.getId(), null, null, pagina, tamano, sortBy, sortDir));
        }
        throw new com.example.backend.config.AccesoDenegadoException("Acceso denegado.");
    }

    @GetMapping("/apadrinado/{apadrinadoId}/paginado")
    public ResponseEntity<PagedResponseDTO<CartaResponseDTO>> listarPorApadrinadoPaginado(
            @PathVariable Long apadrinadoId,
            @RequestParam(required = false) EstadoCarta estado,
            @RequestParam(required = false) String titulo,
            @RequestParam(defaultValue = "0") int pagina,
            @RequestParam(defaultValue = "10") int tamano,
            @RequestParam(defaultValue = "fechaCreacion") String sortBy,
            @RequestParam(defaultValue = "desc") String sortDir) {
        seguridadService.verificarApadrinadoAccesible(apadrinadoId);
        return ResponseEntity.ok(cartaService.listarPorApadrinadoPaginado(
                apadrinadoId, estado, titulo, pagina, tamano, sortBy, sortDir));
    }

    @GetMapping("/expediente/{expedienteId}/paginado")
    public ResponseEntity<PagedResponseDTO<CartaResponseDTO>> listarPorExpedientePaginado(
            @PathVariable Long expedienteId,
            @RequestParam(required = false) EstadoCarta estado,
            @RequestParam(required = false) String titulo,
            @RequestParam(defaultValue = "0") int pagina,
            @RequestParam(defaultValue = "10") int tamano,
            @RequestParam(defaultValue = "fechaCreacion") String sortBy,
            @RequestParam(defaultValue = "desc") String sortDir) {
        seguridadService.verificarExpedienteAccesible(expedienteId);
        return ResponseEntity.ok(cartaService.listarPorExpedientePaginado(
                expedienteId, estado, titulo, pagina, tamano, sortBy, sortDir));
    }
}
