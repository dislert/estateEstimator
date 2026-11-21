package com.example.estateestimator.security;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import java.util.UUID;

import javax.crypto.SecretKey;

import org.springframework.stereotype.Service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

/** Выпуск и проверка JWT access-токенов (HS256). */
@Service
public class JwtService {

    private final SecretKey key;
    private final long ttlSeconds;

    public JwtService(JwtProperties props) {
        byte[] secretBytes = props.secret().getBytes(StandardCharsets.UTF_8);
        if (secretBytes.length < 32) {
            throw new IllegalStateException("app.jwt.secret должен быть не короче 32 байт для HS256");
        }
        this.key = Keys.hmacShaKeyFor(secretBytes);
        this.ttlSeconds = Duration.ofMinutes(props.ttlMinutes()).toSeconds();
    }

    /** sub = id пользователя; email и роли — в клеймах, чтобы защищённые маршруты были stateless. */
    public String issueToken(UUID userId, String email, List<String> roles) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(userId.toString())
                .claim("email", email)
                .claim("roles", roles)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusSeconds(ttlSeconds)))
                .signWith(key, Jwts.SIG.HS256)
                .compact();
    }

    /** Проверяет подпись и срок годности; при нарушении бросает JwtException. */
    public Jws<Claims> parse(String token) {
        return Jwts.parser().verifyWith(key).build().parseSignedClaims(token);
    }

    public long ttlSeconds() {
        return ttlSeconds;
    }
}
