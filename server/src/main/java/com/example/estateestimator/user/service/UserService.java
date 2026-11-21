package com.example.estateestimator.user.service;

import java.util.UUID;

import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.estateestimator.user.dto.UserDto;
import com.example.estateestimator.user.entity.User;
import com.example.estateestimator.user.exception.AccountBlockedException;
import com.example.estateestimator.user.repository.UserRepository;

@Service
public class UserService {

    private final UserRepository users;

    public UserService(UserRepository users) {
        this.users = users;
    }

    /**
     * Профиль текущего пользователя. Данные читаются из БД, а не из токена:
     * так они актуальны после блокировки или изменения профиля.
     */
    @Transactional(readOnly = true)
    public UserDto getCurrentUser(UUID userId) {
        User user = users.findByIdWithRoles(userId)
                .orElseThrow(() -> new BadCredentialsException("Пользователь не найден"));
        if (user.isBlocked()) {
            throw new AccountBlockedException();
        }
        return UserDto.from(user);
    }
}
