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

import com.example.backend.dto.ActividadEstadoDTO;
import com.example.backend.dto.ActividadRequestDTO;
import com.example.backend.dto.ActividadResponseDTO;
import com.example.backend.dto.PagedResponseDTO;
import com.example.backend.dto.HistorialActividadResponseDTO;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Coordinador;
import com.example.backend.entity.EstadoActividad;
import com.example.backend.service.ActividadService;
import com.example.backend.service.HistorialActividadService;
import com.example.backend.service.SeguridadService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/actividades")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class ActividadController {

    private final ActividadService actividadService;
    private final HistorialActividadService historialActividadService;
    private final SeguridadService seguridadService;

    @GetMapping
    public ResponseEntity<List<ActividadResponseDTO>> listarTodas() {
        // FASE B: cada usuario solo ve las actividades que le corresponden
        Coordinador coordinador = seguridadService.coordinadorActual();
        if (coordinador != null) {
            return ResponseEntity.ok(actividadService.listarPorCoordinador(coordinador.getId(), null));
        }
        Apadrinado apadrinado = seguridadService.apadrinadoActual();
        if (apadrinado != null) {
            return ResponseEntity.ok(actividadService.listarPorApadrinado(apadrinado.getId(), null));
        }
        throw new com.example.backend.config.AccesoDenegadoException("Acceso denegado.");
    }

    @GetMapping("/{id}")
    public ResponseEntity<ActividadResponseDTO> obtenerPorId(@PathVariable Long id) {
        seguridadService.verificarActividadAccesible(id);
        return ResponseEntity.ok(actividadService.obtenerPorId(id));
    }

    @GetMapping("/apadrinado/{apadrinadoId}")
    public ResponseEntity<List<ActividadResponseDTO>> listarPorApadrinado(
            @PathVariable Long apadrinadoId,
            @RequestParam(required = false) EstadoActividad estado) {
        seguridadService.verificarApadrinadoAccesible(apadrinadoId);
        return ResponseEntity.ok(actividadService.listarPorApadrinado(apadrinadoId, estado));
    }

    @GetMapping("/coordinador/{coordinadorId}")
    public ResponseEntity<List<ActividadResponseDTO>> listarPorCoordinador(
            @PathVariable Long coordinadorId,
            @RequestParam(required = false) EstadoActividad estado) {
        seguridadService.verificarCoordinadorPropio(coordinadorId);
        return ResponseEntity.ok(actividadService.listarPorCoordinador(coordinadorId, estado));
    }

    @PostMapping
    public ResponseEntity<ActividadResponseDTO> crear(@RequestBody ActividadRequestDTO request) {
        // FASE B: solo coordinadores; la actividad se asigna al coordinador autenticado
        seguridadService.requerirCoordinador();
        Coordinador coordinador = seguridadService.coordinadorActual();
        request.setCoordinadorId(coordinador.getId());

        if (request.getApadrinadoId() != null) {
            seguridadService.verificarApadrinadoAccesible(request.getApadrinadoId());
        }

        ActividadResponseDTO nueva = actividadService.crear(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(nueva);
    }

    @PostMapping("/masiva")
    public ResponseEntity<List<ActividadResponseDTO>> crearMasiva(@RequestBody ActividadRequestDTO request) {
        // FASE B: solo coordinadores; asignación dentro de su propia comunidad
        seguridadService.requerirCoordinador();
        Coordinador coordinador = seguridadService.coordinadorActual();
        request.setCoordinadorId(coordinador.getId());

        if (request.getApadrinadoIds() != null) {
            for (Long apadrinadoId : request.getApadrinadoIds()) {
                seguridadService.verificarApadrinadoAccesible(apadrinadoId);
            }
        }

        List<ActividadResponseDTO> creadas = actividadService.crearMasiva(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(creadas);
    }

    @PutMapping("/{id}")
    public ResponseEntity<ActividadResponseDTO> actualizar(
            @PathVariable Long id,
            @RequestBody ActividadRequestDTO request) {
        // FASE B: la edición de actividades es exclusiva del coordinador responsable
        seguridadService.requerirCoordinador();
        seguridadService.verificarActividadAccesible(id);
        Coordinador coordinador = seguridadService.coordinadorActual();
        request.setCoordinadorId(coordinador.getId());
        return ResponseEntity.ok(actividadService.actualizar(id, request));
    }

    @PatchMapping("/{id}/estado")
    public ResponseEntity<ActividadResponseDTO> cambiarEstado(
            @PathVariable Long id,
            @RequestBody ActividadEstadoDTO request) {
        // FASE B: revisión/estados solo por el coordinador responsable
        seguridadService.requerirCoordinador();
        seguridadService.verificarActividadAccesible(id);
        return ResponseEntity.ok(actividadService.cambiarEstado(id, request));
    }

    /**
     * FASE E: marca una actividad como VENCIDO (fecha límite pasada sin entrega).
     */
    @PostMapping("/{id}/vencido")
    public ResponseEntity<ActividadResponseDTO> marcarVencido(@PathVariable Long id) {
        seguridadService.requerirCoordinador();
        seguridadService.verificarActividadAccesible(id);
        return ResponseEntity.ok(actividadService.marcarVencido(id));
    }

    /**
     * FASE E: marca como VENCIDO todas las actividades vencidas de la
     * comunidad bajo la responsabilidad del coordinador autenticado.
     */
    @PostMapping("/marcar-vencidos")
    public ResponseEntity<List<ActividadResponseDTO>> marcarVencidos() {
        seguridadService.requerirCoordinador();
        Coordinador coordinador = seguridadService.coordinadorActual();
        return ResponseEntity.ok(actividadService.marcarVencidasDelCoordinador(coordinador.getId()));
    }

    @GetMapping("/{id}/historial")
    public ResponseEntity<List<HistorialActividadResponseDTO>> obtenerHistorialPorActividad(@PathVariable Long id) {
        seguridadService.verificarActividadAccesible(id);
        return ResponseEntity.ok(historialActividadService.listarPorActividad(id));
    }

    @GetMapping("/apadrinado/{apadrinadoId}/historial")
    public ResponseEntity<List<HistorialActividadResponseDTO>> obtenerHistorialPorApadrinado(@PathVariable Long apadrinadoId) {
        seguridadService.verificarApadrinadoAccesible(apadrinadoId);
        return ResponseEntity.ok(historialActividadService.listarPorApadrinado(apadrinadoId));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        seguridadService.requerirCoordinador();
        seguridadService.verificarActividadAccesible(id);
        actividadService.eliminar(id);
        return ResponseEntity.noContent().build();
    }

    // ==================== ENDPOINTS PAGINADOS ====================

    @GetMapping("/paginado")
    public ResponseEntity<PagedResponseDTO<ActividadResponseDTO>> listarTodasPaginado(
            @RequestParam(defaultValue = "0") int pagina,
            @RequestParam(defaultValue = "10") int tamano,
            @RequestParam(defaultValue = "fechaCreacion") String sortBy,
            @RequestParam(defaultValue = "desc") String sortDir) {
        Coordinador coordinador = seguridadService.coordinadorActual();
        if (coordinador != null) {
            return ResponseEntity.ok(actividadService.listarPorCoordinadorPaginado(
                    coordinador.getId(), null, null, pagina, tamano, sortBy, sortDir));
        }
        Apadrinado apadrinado = seguridadService.apadrinadoActual();
        if (apadrinado != null) {
            return ResponseEntity.ok(actividadService.listarPorApadrinadoPaginado(
                    apadrinado.getId(), null, null, pagina, tamano, sortBy, sortDir));
        }
        throw new com.example.backend.config.AccesoDenegadoException("Acceso denegado.");
    }

    @GetMapping("/apadrinado/{apadrinadoId}/paginado")
    public ResponseEntity<PagedResponseDTO<ActividadResponseDTO>> listarPorApadrinadoPaginado(
            @PathVariable Long apadrinadoId,
            @RequestParam(required = false) EstadoActividad estado,
            @RequestParam(required = false) String titulo,
            @RequestParam(defaultValue = "0") int pagina,
            @RequestParam(defaultValue = "10") int tamano,
            @RequestParam(defaultValue = "fechaCreacion") String sortBy,
            @RequestParam(defaultValue = "desc") String sortDir) {
        seguridadService.verificarApadrinadoAccesible(apadrinadoId);
        return ResponseEntity.ok(actividadService.listarPorApadrinadoPaginado(
                apadrinadoId, estado, titulo, pagina, tamano, sortBy, sortDir));
    }

    @GetMapping("/coordinador/{coordinadorId}/paginado")
    public ResponseEntity<PagedResponseDTO<ActividadResponseDTO>> listarPorCoordinadorPaginado(
            @PathVariable Long coordinadorId,
            @RequestParam(required = false) EstadoActividad estado,
            @RequestParam(required = false) String titulo,
            @RequestParam(defaultValue = "0") int pagina,
            @RequestParam(defaultValue = "10") int tamano,
            @RequestParam(defaultValue = "fechaCreacion") String sortBy,
            @RequestParam(defaultValue = "desc") String sortDir) {
        seguridadService.verificarCoordinadorPropio(coordinadorId);
        return ResponseEntity.ok(actividadService.listarPorCoordinadorPaginado(
                coordinadorId, estado, titulo, pagina, tamano, sortBy, sortDir));
    }

    @GetMapping("/estado/{estado}/paginado")
    public ResponseEntity<PagedResponseDTO<ActividadResponseDTO>> listarPorEstadoPaginado(
            @PathVariable EstadoActividad estado,
            @RequestParam(defaultValue = "0") int pagina,
            @RequestParam(defaultValue = "10") int tamano,
            @RequestParam(defaultValue = "fechaCreacion") String sortBy,
            @RequestParam(defaultValue = "desc") String sortDir) {
        Coordinador coordinador = seguridadService.coordinadorActual();
        if (coordinador != null) {
            return ResponseEntity.ok(actividadService.listarPorCoordinadorPaginado(
                    coordinador.getId(), estado, null, pagina, tamano, sortBy, sortDir));
        }
        Apadrinado apadrinado = seguridadService.apadrinadoActual();
        if (apadrinado != null) {
            return ResponseEntity.ok(actividadService.listarPorApadrinadoPaginado(
                    apadrinado.getId(), estado, null, pagina, tamano, sortBy, sortDir));
        }
        throw new com.example.backend.config.AccesoDenegadoException("Acceso denegado.");
    }
}
