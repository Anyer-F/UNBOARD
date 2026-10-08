package com.example.backend.service;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Iterator;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Service;

import lombok.extern.slf4j.Slf4j;

/**
 * Servicio de apoyo para el flujo de recuperación de contraseña.
 *
 * Para el prototipo, los códigos se gestionan en memoria con expiración
 * de 10 minutos. En producción se recomienda persistirlos en base de datos
 * y enviarlos por correo electrónico real.
 */
@Service
@Slf4j
public class PasswordResetService {

    private static final int EXPIRACION_MINUTOS = 10;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final Map<String, CodigoReset> codigosPorCorreo = new ConcurrentHashMap<>();

    /**
     * Genera y almacena un código de 6 dígitos para el correo indicado.
     * @return el código generado (en producción se enviaría por correo y no se devolvería)
     */
    public String generarCodigo(String correo) {
        String codigo = String.format("%06d", RANDOM.nextInt(1_000_000));
        codigosPorCorreo.put(correo.toLowerCase().trim(),
                new CodigoReset(codigo, LocalDateTime.now().plusMinutes(EXPIRACION_MINUTOS)));
        log.info("[PROTOTIPO] Código de recuperación generado para {}: {} (expira en {} min)",
                correo, codigo, EXPIRACION_MINUTOS);
        return codigo;
    }

    /**
     * Valida que exista un código vigente y coincidente para el correo.
     */
    public boolean validarCodigo(String correo, String codigo) {
        limpiarExpirados();
        if (correo == null || codigo == null) {
            return false;
        }
        CodigoReset almacenado = codigosPorCorreo.get(correo.toLowerCase().trim());
        return almacenado != null
                && !almacenado.expirado()
                && almacenado.codigo().equals(codigo.trim());
    }

    /**
     * Elimina el código una vez utilizado.
     */
    public void invalidarCodigo(String correo) {
        codigosPorCorreo.remove(correo.toLowerCase().trim());
    }

    private void limpiarExpirados() {
        Iterator<Map.Entry<String, CodigoReset>> it = codigosPorCorreo.entrySet().iterator();
        while (it.hasNext()) {
            if (it.next().getValue().expirado()) {
                it.remove();
            }
        }
    }

    private record CodigoReset(String codigo, LocalDateTime expiracion) {
        boolean expirado() {
            return LocalDateTime.now().isAfter(expiracion);
        }
    }
}
