package ru.bbmanager.db;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/** Проверяет, что миграция V1 применяется на настоящем PostgreSQL. Нужен запущенный Docker. */
@Testcontainers
class SchemaMigrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");

    @Test
    void migrationAppliesAndCreatesCoreTables() throws Exception {
        Flyway flyway = Flyway.configure()
                .dataSource(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())
                .locations("classpath:db/migration")
                .load();

        assertTrue(flyway.migrate().success);

        try (Connection connection = DriverManager.getConnection(
                postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword());
             Statement statement = connection.createStatement();
             ResultSet rs = statement.executeQuery(
                     "select count(*) from information_schema.tables "
                             + "where table_schema = 'public' "
                             + "and table_name in ('app_user','game_save','club','match')")) {
            rs.next();
            assertEquals(4, rs.getInt(1));
        }
    }
}
