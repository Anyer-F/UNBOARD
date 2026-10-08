package com.example.backend.service;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Tareas de mantenimiento programadas del módulo de actividades.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class MantenimientoActividades {

    private final ActividadService actividadService;

    /**
     * Cada día a las 06:00 marca como VENCIDO las actividades
     * cuya fecha límite ya pasó sin entrega registrada.
     */
    @Scheduled(cron = "0 0 6 * * *")
    public void marcarActividadesVencidas() {
        int marcadas = actividadService.marcarVencidasGlobal();
        if (marcadas > 0) {
            log.info("Actividades marcadas como vencidas automáticamente: {}", marcadas);
        }
    }
}
