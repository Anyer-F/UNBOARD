package com.example.backend.dto;

public class ChatbotResponseDTO {

    private String respuesta;

    public ChatbotResponseDTO() {
    }

    public ChatbotResponseDTO(String respuesta) {
        this.respuesta = respuesta;
    }

    public String getRespuesta() {
        return respuesta;
    }

    public void setRespuesta(String respuesta) {
        this.respuesta = respuesta;
    }
}