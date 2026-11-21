package com.example.estateestimator.security;

import java.util.UUID;

/** Principal аутентифицированного пользователя (из JWT). */
public record AuthUser(UUID id, String email) {}
