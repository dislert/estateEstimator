package com.example.estateestimator.auth.dto;

import com.example.estateestimator.user.dto.UserDto;

/** Ответ регистрации/входа: access-токен JWT и профиль пользователя. */
public record AuthResponse(
        String accessToken,
        String tokenType,
        long expiresIn,
        UserDto user
) {}
