package com.example.estateestimator.user.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.example.estateestimator.user.entity.Role;

/** Справочник ролей: используется при регистрации для назначения роли по коду. */
public interface RoleRepository extends JpaRepository<Role, Integer> {

    Optional<Role> findByCode(String code);
}
