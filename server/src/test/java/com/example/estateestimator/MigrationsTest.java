package com.example.estateestimator;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;

import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.output.MigrateResult;
import org.junit.jupiter.api.Test;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * Прогоняет миграции на чистой базе PostgreSQL+PostGIS и выполняет контрольные запросы (db/verify.sql).
 * Требуется Docker; без него тесты пропускаются.
 */
@Testcontainers(disabledWithoutDocker = true)
class MigrationsTest {

    private static final String SCHEMA = "classpath:db/migration";
    private static final String DEV = "classpath:db/dev";

    @Container
    static final PostgreSQLContainer PG = new PostgreSQLContainer(
            DockerImageName.parse("postgis/postgis:16-3.4").asCompatibleSubstituteFor("postgres"))
            .withDatabaseName("app")
            .withUsername("app")
            .withPassword("app");

    private static Flyway flyway(String... locations) {
        return Flyway.configure()
                .dataSource(PG.getJdbcUrl(), PG.getUsername(), PG.getPassword())
                .locations(locations)
                .cleanDisabled(false)
                .load();
    }

    private static Connection connection() throws SQLException {
        return DriverManager.getConnection(PG.getJdbcUrl(), PG.getUsername(), PG.getPassword());
    }

    private static long count(String table) throws SQLException {
        try (Connection c = connection();
             Statement s = c.createStatement();
             ResultSet rs = s.executeQuery("SELECT count(*) FROM " + table)) {
            rs.next();
            return rs.getLong(1);
        }
    }

    private static void runVerifyScript() throws Exception {
        String sql;
        try (var in = MigrationsTest.class.getResourceAsStream("/db/verify.sql")) {
            sql = new String(in.readAllBytes(), StandardCharsets.UTF_8);
        }
        try (Connection c = connection(); Statement s = c.createStatement()) {
            s.execute(sql);
        }
    }

    @Test
    void schemaAndReferenceData_passVerification() throws Exception {
        Flyway f = flyway(SCHEMA);
        f.clean();
        MigrateResult result = f.migrate();

        assertEquals(2, result.migrationsExecuted);
        assertEquals(3, count("roles"));
        assertEquals(4, count("data_sources"));
        assertEquals(0, count("users"), "в prod-миграциях тестовых пользователей быть не должно");
        runVerifyScript();
    }

    @Test
    void migrationsAreReproducibleOnCleanDatabase() {
        Flyway f = flyway(SCHEMA);
        assertDoesNotThrow(() -> {
            f.clean();
            f.migrate();
            f.clean();
            f.migrate();
            f.validate();
        });
    }

    @Test
    void devProfileLoadsTestData() throws Exception {
        Flyway f = flyway(SCHEMA, DEV);
        f.clean();
        MigrateResult result = f.migrate();

        assertEquals(3, result.migrationsExecuted);
        assertEquals(3, count("users"));
        assertEquals(3, count("properties"));
        assertEquals(3, count("locations"));
        assertEquals(2, count("photos"));
        assertEquals(1, count("chats"));
        assertEquals(1, count("applications"));
        assertEquals(2, count("messages"));
        assertEquals(4, count("hud_market_data"));
        assertEquals(8, count("market_history"));
        assertEquals(1, count("properties WHERE status = 'archived'"));
        runVerifyScript();
    }
}
