package com.example.estateestimator.security;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** Настройки JWT: секрет HS256 (>= 32 байт) и время жизни access-токена. */
@ConfigurationProperties(prefix = "app.jwt")
public record JwtProperties(
        String secret,
        long ttlMinutes
) {}
