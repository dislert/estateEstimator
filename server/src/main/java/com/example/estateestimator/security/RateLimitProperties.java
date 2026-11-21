package com.example.estateestimator.security;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** Лимиты запросов к эндпоинтам авторизации (скользящее окно 1 минута, на IP). */
@ConfigurationProperties(prefix = "app.rate-limit")
public record RateLimitProperties(
        int loginPerMinute,
        int registerPerMinute
) {}
