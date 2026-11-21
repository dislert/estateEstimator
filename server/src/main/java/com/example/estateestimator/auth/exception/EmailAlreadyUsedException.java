package com.example.estateestimator.auth.exception;

/** Email уже зарегистрирован (HTTP 409). */
public class EmailAlreadyUsedException extends RuntimeException {
    public EmailAlreadyUsedException(String email) {
        super("Пользователь с email '" + email + "' уже зарегистрирован");
    }
}
