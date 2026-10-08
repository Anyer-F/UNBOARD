package com.example.backend.service;

import org.springframework.stereotype.Service;

import com.example.backend.dto.ChatbotRequestDTO;
import com.example.backend.dto.ChatbotResponseDTO;

@Service
public class ChatbotService {

    public ChatbotResponseDTO procesarMensaje(ChatbotRequestDTO request) {

        String mensaje = request.getMensaje();

        if (mensaje == null || mensaje.trim().isEmpty()) {
            return new ChatbotResponseDTO(
                    "Por favor, escribe una pregunta."
            );
        }

        String texto = mensaje.toLowerCase();

        String respuesta;

        if (texto.contains("actividad")) {

            respuesta = "Puedes consultar tus actividades desde el módulo de Actividades.";

        } else if (texto.contains("documento")) {

            respuesta = "Puedes consultar los documentos asociados a tu expediente.";

        } else if (texto.contains("expediente")) {

            respuesta = "El expediente contiene la información y documentación registrada del apadrinado.";

        } else if (texto.contains("hola")) {

            respuesta = "Hola. Soy el asistente de gestión documental de UNBOUND. ¿En qué puedo ayudarte?";

        } else {

            respuesta = "No encontré información relacionada con tu consulta. Puedes preguntar sobre actividades, documentos o expedientes.";
        }

        return new ChatbotResponseDTO(respuesta);
    }
}