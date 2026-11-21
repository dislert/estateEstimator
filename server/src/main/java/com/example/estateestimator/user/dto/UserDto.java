package com.example.estateestimator.user.dto;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import com.example.estateestimator.user.entity.Role;
import com.example.estateestimator.user.entity.User;

/** Публичное представление пользователя (без password_hash). */
public record UserDto(
        UUID id,
        String email,
        String firstName,
        String lastName,
        String gender,
        String avatarUrl,
        List<String> roles,
        LocalDateTime createdAt
) {
    public static UserDto from(User user) {
        List<String> roleCodes = user.getRoles().stream()
                .map(Role::getCode)
                .sorted()
                .toList();
        return new UserDto(user.getId(), user.getEmail(), user.getFirstName(), user.getLastName(),
                user.getGender(), user.getAvatarUrl(), roleCodes, user.getCreatedAt());
    }
}
