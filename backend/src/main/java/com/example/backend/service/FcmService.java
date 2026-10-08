package com.example.backend.service;

import java.util.concurrent.ExecutionException;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import com.google.firebase.messaging.TopicManagementResponse;
import com.google.firebase.messaging.WebpushConfig;
import com.google.firebase.messaging.WebpushFcmOptions;

import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;

@Service
@Slf4j
public class FcmService implements FcmServiceInterface {

    @Value("${firebase.service-account:}")
    private String serviceAccountPath;

    private FirebaseApp firebaseApp;

    @PostConstruct
    public void init() {
        try {
            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseOptions options;
                if (serviceAccountPath != null && !serviceAccountPath.isEmpty()) {
                    try {
                        options = FirebaseOptions.builder()
                                .setCredentials(com.google.auth.oauth2.GoogleCredentials.fromStream(
                                        new ClassPathResource(serviceAccountPath).getInputStream()))
                                .build();
                    } catch (Exception e) {
                        log.warn("No se pudo cargar serviceAccountKey.json: {}", e.getMessage());
                        log.warn("Las notificaciones push no estarán disponibles hasta configurar Firebase correctamente.");
                        return;
                    }
                } else {
                    options = FirebaseOptions.builder()
                            .setCredentials(com.google.auth.oauth2.GoogleCredentials.getApplicationDefault())
                            .build();
                }
                firebaseApp = FirebaseApp.initializeApp(options);
                log.info("Firebase Admin SDK inicializado correctamente");
            } else {
                firebaseApp = FirebaseApp.getInstance();
            }
        } catch (Exception e) {
            log.warn("Firebase Admin SDK no inicializado: {}", e.getMessage());
            log.warn("Las notificaciones push no estarán disponibles hasta configurar Firebase correctamente.");
        }
    }

    public boolean enviarNotificacionPush(String token, String titulo, String cuerpo) {
        try {
            Notification notification = Notification.builder()
                    .setTitle(titulo)
                    .setBody(cuerpo)
                    .build();

            Message message = Message.builder()
                    .setToken(token)
                    .setNotification(notification)
                    .build();

            String response = FirebaseMessaging.getInstance(firebaseApp).send(message);
            log.info("Notificación push enviada correctamente: {}", response);
            return true;
        } catch (Exception e) {
            log.error("Error al enviar notificación push: {}", e.getMessage());
            return false;
        }
    }

    public boolean enviarNotificacionPushData(String token, String titulo, String cuerpo, String tipo, Long idReferencia) {
        try {
            Notification notification = Notification.builder()
                    .setTitle(titulo)
                    .setBody(cuerpo)
                    .build();

            Message message = Message.builder()
                    .setToken(token)
                    .setNotification(notification)
                    .putData("tipo", tipo)
                    .putData("idReferencia", String.valueOf(idReferencia))
                    .build();

            String response = FirebaseMessaging.getInstance(firebaseApp).send(message);
            log.info("Notificación push con datos enviada correctamente: {}", response);
            return true;
        } catch (Exception e) {
            log.error("Error al enviar notificación push con datos: {}", e.getMessage());
            return false;
        }
    }

    public boolean enviarNotificacionATema(String tema, String titulo, String cuerpo) {
        try {
            Notification notification = Notification.builder()
                    .setTitle(titulo)
                    .setBody(cuerpo)
                    .build();

            Message message = Message.builder()
                    .setTopic(tema)
                    .setNotification(notification)
                    .build();

            String response = FirebaseMessaging.getInstance(firebaseApp).send(message);
            log.info("Notificación push a tema '{}' enviada correctamente: {}", tema, response);
            return true;
        } catch (Exception e) {
            log.error("Error al enviar notificación a tema '{}': {}", tema, e.getMessage());
            return false;
        }
    }

    public boolean suscribirATema(String token, String tema) {
        try {
            TopicManagementResponse response = FirebaseMessaging.getInstance(firebaseApp)
                    .subscribeToTopic(java.util.Collections.singletonList(token), tema);
            log.info("Token suscrito a tema '{}': {} éxitos, {} fallos", tema, response.getSuccessCount(), response.getFailureCount());
            return response.getFailureCount() == 0;
        } catch (Exception e) {
            log.error("Error al suscribir token a tema '{}': {}", tema, e.getMessage());
            return false;
        }
    }

    public boolean desuscribirDeTema(String token, String tema) {
        try {
            TopicManagementResponse response = FirebaseMessaging.getInstance(firebaseApp)
                    .unsubscribeFromTopic(java.util.Collections.singletonList(token), tema);
            log.info("Token desuscrito de tema '{}': {} éxitos, {} fallos", tema, response.getSuccessCount(), response.getFailureCount());
            return response.getFailureCount() == 0;
        } catch (Exception e) {
            log.error("Error al desuscribir token de tema '{}': {}", tema, e.getMessage());
            return false;
        }
    }

    public boolean enviarNotificacionWebPush(String token, String titulo, String cuerpo, String iconUrl) {
        try {
            Notification notification = Notification.builder()
                    .setTitle(titulo)
                    .setBody(cuerpo)
                    .setImage(iconUrl)
                    .build();

            WebpushConfig webpushConfig = WebpushConfig.builder()
                    .setFcmOptions(WebpushFcmOptions.builder()
                            .setLink("https://unbound-huehuetenango.org")
                            .build())
                    .build();

            Message message = Message.builder()
                    .setToken(token)
                    .setNotification(notification)
                    .setWebpushConfig(webpushConfig)
                    .build();

            String response = FirebaseMessaging.getInstance(firebaseApp).send(message);
            log.info("Notificación web push enviada correctamente: {}", response);
            return true;
        } catch (Exception e) {
            log.error("Error al enviar notificación web push: {}", e.getMessage());
            return false;
        }
    }
}
