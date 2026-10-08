package com.example.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FcmTokenRequestDTO {

    @NotBlank(message = "El token FCM es obligatorio")
    private String fcmToken;

    private String dispositivo;
}
