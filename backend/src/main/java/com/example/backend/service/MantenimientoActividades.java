package com.example.backend.service;

import java.time.LocalDate;
import java.util.EnumSet;
import java.util.List;

import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.entity.Asignacion;
import com.example.backend.entity.EntidadHistorial;
import com.example.backend.entity.EstadoActividad;
import com.example.backend.entity.TipoNotificacion;
import com.example.backend.repository.AsignacionRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Tareas programadas de las actividades:
 * - Vencido: la fecha límite pasó sin que la entrega fuera enviada.
 * - Próxima fecha límite: recordatorio al apadrinado.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class MantenimientoActividades {

    private final AsignacionRepository asignacionRepository;
    private final NotificacionService notificacionService;
    private final HistorialActividadService historialService;

    @EventListener(ApplicationReadyEvent.class)
    public void alIniciar() {
        ejecutar();
    }

    /** Cada hora. */
    @Scheduled(cron = "0 0 * * * *")
    public void programado() {
        ejecutar();
    }

    private void ejecutar() {
        try {
            int vencidas = marcarVencidas();
            int recordatorios = enviarRecordatorios();
            if (vencidas > 0 || recordatorios > 0) {
                log.info("Mantenimiento: {} tarea(s) vencida(s), {} recordatorio(s)", vencidas, recordatorios);
            }
        } catch (Exception e) {
            log.warn("Mantenimiento de actividades no completado: {}", e.getMessage());
        }
    }

    @Transactional
    public int marcarVencidas() {
        List<Asignacion> lista = asignacionRepository.findTareasVencidas(LocalDate.now(),
                EnumSet.of(EstadoActividad.PENDIENTE, EstadoActividad.EN_PROGRESO));
        for (Asignacion s : lista) {
            EstadoActividad anterior = s.getEstado();
            s.setEstado(EstadoActividad.VENCIDO);
            historialService.registrarAsignacion(s, EntidadHistorial.ASIGNACION, s.getId(), anterior,
                    EstadoActividad.VENCIDO, "TAREA VENCIDA",
                    "Fecha límite: " + s.getActividad().getFechaLimite(), null);
            notificacionService.notificar(s.getApadrinado().getUsuario(), "Actividad vencida",
                    "La fecha límite de '" + s.getActividad().getTitulo() + "' pasó sin que se enviara la entrega.",
                    TipoNotificacion.ACTIVIDAD_VENCIDA, s.getId(), "ASIGNACION");
        }
        asignacionRepository.saveAll(lista);
        return lista.size();
    }

    @Transactional
    public int enviarRecordatorios() {
        LocalDate hoy = LocalDate.now();
        List<Asignacion> lista = asignacionRepository.findParaRecordatorio(hoy,
                hoy.plusDays(ConvertidorDTO.DIAS_PROXIMA_A_VENCER),
                EnumSet.of(EstadoActividad.PENDIENTE, EstadoActividad.EN_PROGRESO,
                        EstadoActividad.CORRECCION_SOLICITADA));
        for (Asignacion s : lista) {
            LocalDate limite = s.getActividad().getFechaLimite();
            long dias = java.time.temporal.ChronoUnit.DAYS.between(hoy, limite);
            String cuando = dias == 0 ? "hoy" : dias == 1 ? "mañana" : "en " + dias + " días";
            notificacionService.notificar(s.getApadrinado().getUsuario(), "Próxima fecha límite",
                    "La actividad '" + s.getActividad().getTitulo() + "' vence " + cuando + " (" + limite + ").",
                    TipoNotificacion.PROXIMA_FECHA_LIMITE, s.getId(), "ASIGNACION");
            s.setRecordatorioEnviado(true);
        }
        asignacionRepository.saveAll(lista);
        return lista.size();
    }
}
