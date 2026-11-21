-- V3: отзыв access-токенов при выходе из системы.
-- Храним jti (JWT ID) до истечения срока действия токена.
CREATE TABLE revoked_tokens (
    jti        VARCHAR(64) PRIMARY KEY,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_revoked_tokens_expires_at ON revoked_tokens(expires_at);
