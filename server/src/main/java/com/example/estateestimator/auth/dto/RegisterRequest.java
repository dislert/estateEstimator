package com.example.estateestimator.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Запрос регистрации. role — необязательно: buyer (по умолчанию) или owner; admin через API не назначается. */
public record RegisterRequest(
        @NotBlank(message = "Email обязателен")
        @Email(message = "Некорректный формат email")
        @Size(max = 255, message = "Email не должен превышать 255 символов")
        String email,

        @NotBlank(message = "Пароль обязателен")
        @Size(min = 8, max = 72, message = "Пароль должен быть от 8 до 72 символов")
        String password,

        @NotBlank(message = "Имя обязательно")
        @Size(max = 100, message = "Имя не должно превышать 100 символов")
        String firstName,

        @NotBlank(message = "Фамилия обязательна")
        @Size(max = 100, message = "Фамилия не должна превышать 100 символов")
        String lastName,

        @Pattern(regexp = "male|female", message = "Пол: male или female")
        String gender,

        @Pattern(regexp = "buyer|owner", message = "Роль: buyer или owner")
        String role
) {}
