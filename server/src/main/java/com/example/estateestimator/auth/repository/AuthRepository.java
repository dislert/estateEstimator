package com.example.estateestimator.auth.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.example.estateestimator.user.entity.User;

/**
 * Репозиторий модуля авторизации: операции с учётной записью, нужные для входа и регистрации.
 * Профильные запросы находятся в user.repository.UserRepository.
 */
public interface AuthRepository extends JpaRepository<User, UUID> {

    @EntityGraph(attributePaths = "roles")
    @Query("select distinct u from User u where u.email = :email")
    Optional<User> findByEmailWithRoles(@Param("email") String email);

    boolean existsByEmail(String email);
}
