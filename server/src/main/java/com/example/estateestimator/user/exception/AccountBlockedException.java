package com.example.estateestimator.user.exception;

/** Учётная запись заблокирована (HTTP 403). */
public class AccountBlockedException extends RuntimeException {
    public AccountBlockedException() {
        super("Учётная запись заблокирована");
    }
}
