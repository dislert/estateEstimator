package com.example.estateestimator.common;

import java.util.LinkedHashMap;
import java.util.Map;

import jakarta.servlet.http.HttpServletRequest;

import org.springframework.http.HttpStatus;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import com.example.estateestimator.auth.exception.EmailAlreadyUsedException;
import com.example.estateestimator.user.exception.AccountBlockedException;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    ApiError validation(MethodArgumentNotValidException ex, HttpServletRequest request) {
        Map<String, String> fieldErrors = new LinkedHashMap<>();
        for (FieldError fieldError : ex.getBindingResult().getFieldErrors()) {
            fieldErrors.putIfAbsent(fieldError.getField(), fieldError.getDefaultMessage());
        }
        return new ApiError(java.time.OffsetDateTime.now(), HttpStatus.BAD_REQUEST.value(), "validation_error",
                "Ошибка валидации запроса", request.getRequestURI(), fieldErrors);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    ApiError unreadableBody(HttpMessageNotReadableException ex, HttpServletRequest request) {
        return ApiError.of(HttpStatus.BAD_REQUEST.value(), "malformed_request",
                "Некорректное тело запроса", request.getRequestURI());
    }

    @ExceptionHandler(BadCredentialsException.class)
    @ResponseStatus(HttpStatus.UNAUTHORIZED)
    ApiError badCredentials(BadCredentialsException ex, HttpServletRequest request) {
        // единое сообщение, чтобы не раскрывать, существует ли email
        return ApiError.of(HttpStatus.UNAUTHORIZED.value(), "invalid_credentials",
                "Неверный email или пароль", request.getRequestURI());
    }

    @ExceptionHandler(AccountBlockedException.class)
    @ResponseStatus(HttpStatus.FORBIDDEN)
    ApiError blocked(AccountBlockedException ex, HttpServletRequest request) {
        return ApiError.of(HttpStatus.FORBIDDEN.value(), "account_blocked",
                ex.getMessage(), request.getRequestURI());
    }

    @ExceptionHandler(EmailAlreadyUsedException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    ApiError emailUsed(EmailAlreadyUsedException ex, HttpServletRequest request) {
        return ApiError.of(HttpStatus.CONFLICT.value(), "email_already_used",
                ex.getMessage(), request.getRequestURI());
    }
}
