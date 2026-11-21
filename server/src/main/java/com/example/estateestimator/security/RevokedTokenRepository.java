package com.example.estateestimator.security;

import java.time.Instant;

import org.springframework.data.jpa.repository.JpaRepository;

public interface RevokedTokenRepository extends JpaRepository<RevokedToken, String> {

    /** Удаляет записи, срок действия токенов которых уже истёк. */
    void deleteByExpiresAtBefore(Instant cutoff);
}
