package com.example.estateestimator.user.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.example.estateestimator.user.entity.User;

/** Чтение профиля пользователя. Роли загружаются сразу, чтобы DTO не зависел от открытой сессии. */
public interface UserRepository extends JpaRepository<User, UUID> {

    @EntityGraph(attributePaths = "roles")
    @Query("select distinct u from User u where u.id = :id")
    Optional<User> findByIdWithRoles(@Param("id") UUID id);
}
