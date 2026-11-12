package com.example.backend.config;

/**
 * La operación requiere confirmación explícita del usuario
 * (ej. eliminar una actividad que ya tiene entregas). Responde 409.
 */
public class ConfirmacionRequeridaException extends RuntimeException {

    public ConfirmacionRequeridaException(String mensaje) {
        super(mensaje);
    }
}
