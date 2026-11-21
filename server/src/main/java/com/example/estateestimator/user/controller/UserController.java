package com.example.estateestimator.user.controller;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.estateestimator.security.AuthUser;
import com.example.estateestimator.user.dto.UserDto;
import com.example.estateestimator.user.service.UserService;

/** Защищённые маршруты: доступ только с валидным JWT (Authorization: Bearer <token>). */
@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    /** Профиль текущего пользователя. */
    @GetMapping("/me")
    public UserDto me(@AuthenticationPrincipal AuthUser principal) {
        return userService.getCurrentUser(principal.id());
    }
}
