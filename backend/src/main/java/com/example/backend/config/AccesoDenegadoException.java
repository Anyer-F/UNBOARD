package com.example.backend.config;

/**
 * Excepción lanzada cuando un usuario intenta acceder a un recurso
 * o realizar una operación que no le corresponde según su rol
 * o la propiedad del recurso (RBAC / control de pertenencia).
 */
public class AccesoDenegadoException extends RuntimeException {

    public AccesoDenegadoException(String mensaje) {
        super(mensaje);
    }
}
