package com.example.backend.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.backend.dto.ChatbotRequestDTO;
import com.example.backend.dto.ChatbotResponseDTO;
import com.example.backend.service.ChatbotService;

@RestController
@RequestMapping("/api/chatbot")
@CrossOrigin(origins = "*")
public class ChatbotController {

    private final ChatbotService chatbotService;

    public ChatbotController(ChatbotService chatbotService) {
        this.chatbotService = chatbotService;
    }

    @PostMapping("/mensaje")
    public ResponseEntity<ChatbotResponseDTO> enviarMensaje(
            @RequestBody ChatbotRequestDTO request) {

        ChatbotResponseDTO respuesta =
                chatbotService.procesarMensaje(request);

        return ResponseEntity.ok(respuesta);
    }
}
 