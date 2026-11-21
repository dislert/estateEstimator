package com.example.estateestimator.user.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Справочник ролей (buyer/owner/admin).
 * Заполняется миграциями, поэтому сущность доступна только для чтения.
 */
@Entity
@Table(name = "roles")
public class Role {

    @Id
    private Integer id;

    @Column(nullable = false, unique = true, length = 20)
    private String code;

    @Column(nullable = false, length = 50)
    private String name;

    protected Role() {
        // для JPA
    }

    public Integer getId() {
        return id;
    }

    public String getCode() {
        return code;
    }

    public String getName() {
        return name;
    }
}
