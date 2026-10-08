package com.example.backend.dto;

public class ChatbotRequestDTO {

    private String mensaje;
    private Long usuarioId;

    public ChatbotRequestDTO() {
    }

    public String getMensaje() {
        return mensaje;
    }

    public void setMensaje(String mensaje) {
        this.mensaje = mensaje;
    }

    public Long getUsuarioId() {
        return usuarioId;
    }

    public void setUsuarioId(Long usuarioId) {
        this.usuarioId = usuarioId;
    }
}