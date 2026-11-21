package com.example.estateestimator.security;

import java.time.Instant;
import java.util.Date;

import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import io.jsonwebtoken.Claims;

/** Отзыв access-токенов: logout делает JWT недействительным до истечения его срока. */
@Service
public class TokenRevocationService {

    private final JwtService jwtService;
    private final RevokedTokenRepository revokedTokens;

    public TokenRevocationService(JwtService jwtService, RevokedTokenRepository revokedTokens) {
        this.jwtService = jwtService;
        this.revokedTokens = revokedTokens;
    }

    @Transactional
    public void revoke(String token) {
        Claims claims = jwtService.parse(token).getPayload();
        String jti = claims.getId();
        Date expiration = claims.getExpiration();
        if (jti == null || expiration == null) {
            throw new BadCredentialsException("Токен не содержит обязательных клеймов");
        }

        Instant expiresAt = expiration.toInstant();
        if (!expiresAt.isAfter(Instant.now())) {
            return;
        }

        revokedTokens.save(new RevokedToken(jti, expiresAt));
        // Попутно чистим записи токенов, которые уже не могут быть предъявлены.
        revokedTokens.deleteByExpiresAtBefore(Instant.now());
    }

    @Transactional(readOnly = true)
    public boolean isRevoked(String jti) {
        return jti == null || revokedTokens.existsById(jti);
    }
}
