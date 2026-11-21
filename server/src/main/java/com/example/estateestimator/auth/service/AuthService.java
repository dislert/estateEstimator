package com.example.estateestimator.auth.service;

import java.util.List;
import java.util.Locale;
import java.util.Optional;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.estateestimator.auth.dto.AuthResponse;
import com.example.estateestimator.auth.dto.LoginRequest;
import com.example.estateestimator.auth.dto.RegisterRequest;
import com.example.estateestimator.auth.exception.EmailAlreadyUsedException;
import com.example.estateestimator.auth.repository.AuthRepository;
import com.example.estateestimator.security.JwtService;
import com.example.estateestimator.user.dto.UserDto;
import com.example.estateestimator.user.entity.Role;
import com.example.estateestimator.user.entity.User;
import com.example.estateestimator.user.exception.AccountBlockedException;
import com.example.estateestimator.user.repository.RoleRepository;

@Service
public class AuthService {

    private static final String DEFAULT_ROLE = "buyer";

    private final AuthRepository users;
    private final RoleRepository roles;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    /** Хеш для выравнивания времени ответа, когда пользователь не найден (защита от перебора email по таймингу). */
    private final String dummyHash;

    public AuthService(AuthRepository users, RoleRepository roles,
                       PasswordEncoder passwordEncoder, JwtService jwtService) {
        this.users = users;
        this.roles = roles;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.dummyHash = passwordEncoder.encode("dummy-password-for-timing-equalization");
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        String email = normalizeEmail(request.email());
        String roleCode = request.role() == null ? DEFAULT_ROLE : request.role();

        // Быстрая проверка для понятной ошибки; гонку двух регистраций ловит ограничение БД ниже.
        if (users.existsByEmail(email)) {
            throw new EmailAlreadyUsedException(email);
        }

        Role role = roles.findByCode(roleCode)
                .orElseThrow(() -> new IllegalStateException("Роль не найдена в справочнике: " + roleCode));

        User user = new User(email, passwordEncoder.encode(request.password()),
                request.firstName().trim(), request.lastName().trim(), request.gender());
        user.addRole(role);

        try {
            users.saveAndFlush(user);
        } catch (DataIntegrityViolationException e) {
            throw new EmailAlreadyUsedException(email);
        }
        return toAuthResponse(user);
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        String email = normalizeEmail(request.email());
        Optional<User> found = users.findByEmailWithRoles(email);

        // matches() выполняется всегда, даже если пользователя нет, — одинаковое время ответа
        String hash = found.map(User::getPasswordHash).orElse(dummyHash);
        boolean passwordOk = passwordEncoder.matches(request.password(), hash);
        if (found.isEmpty() || !passwordOk) {
            throw new BadCredentialsException("Неверный email или пароль");
        }

        User user = found.get();
        if (user.isBlocked()) {
            throw new AccountBlockedException();
        }
        return toAuthResponse(user);
    }

    private AuthResponse toAuthResponse(User user) {
        List<String> roleCodes = user.getRoles().stream()
                .map(Role::getCode)
                .sorted()
                .toList();
        String token = jwtService.issueToken(user.getId(), user.getEmail(), roleCodes);
        return new AuthResponse(token, "Bearer", jwtService.ttlSeconds(), UserDto.from(user));
    }

    static String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }
}
