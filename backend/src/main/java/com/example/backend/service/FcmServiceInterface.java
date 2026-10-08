package com.example.backend.service;

public interface FcmServiceInterface {
    boolean enviarNotificacionPush(String token, String titulo, String cuerpo);
    boolean enviarNotificacionPushData(String token, String titulo, String cuerpo, String tipo, Long idReferencia);
    boolean enviarNotificacionATema(String tema, String titulo, String cuerpo);
    boolean suscribirATema(String token, String tema);
    boolean desuscribirDeTema(String token, String tema);
    boolean enviarNotificacionWebPush(String token, String titulo, String cuerpo, String iconUrl);
}
