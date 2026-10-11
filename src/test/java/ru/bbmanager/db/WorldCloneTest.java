package ru.bbmanager.db;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/** Копирование мира из шаблона на настоящем PostgreSQL. Миграции применяются вместе с демо-миром (db/dev). */
@Testcontainers
class WorldCloneTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");

    @BeforeAll
    static void migrate() {
        Flyway.configure()
                .dataSource(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())
                .locations("classpath:db/migration", "classpath:db/dev")
                .load()
                .migrate();
    }

    @Test
    void cloneCopiesWholeWorldAndSelectsClub() throws Exception {
        try (Connection c = DriverManager.getConnection(
                postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())) {
            long userId = scalar(c, "INSERT INTO app_user (email, password_hash) VALUES ('t@test.ru', 'x') RETURNING id");
            long templateId = scalar(c, "SELECT id FROM game_save WHERE is_template");
            long templateClub = scalar(c, "SELECT id FROM club WHERE save_id = " + templateId + " AND name = 'Демо Пермь'");
            long saveId = scalar(c, "INSERT INTO game_save (user_id, name, game_date) "
                    + "VALUES (" + userId + ", 'Тест', DATE '2026-01-01') RETURNING id");

            long newClub = scalar(c, "SELECT clone_world(" + templateId + ", " + saveId + ", " + templateClub + ")");

            assertEquals(newClub, scalar(c, "SELECT user_club_id FROM game_save WHERE id = " + saveId));
            assertNotEquals(templateClub, newClub);
            for (String table : new String[] {"club", "city", "player", "coach", "staff", "contract", "sponsor"}) {
                assertEquals(
                        scalar(c, "SELECT COUNT(*) FROM " + table + " WHERE save_id = " + templateId),
                        scalar(c, "SELECT COUNT(*) FROM " + table + " WHERE save_id = " + saveId),
                        "число записей в " + table);
            }
            // ссылки внутри партии не ведут в шаблон
            assertEquals(0, scalar(c, "SELECT COUNT(*) FROM club c JOIN city ci ON ci.id = c.city_id "
                    + "WHERE c.save_id = " + saveId + " AND ci.save_id <> c.save_id"));
            assertEquals(0, scalar(c, "SELECT COUNT(*) FROM contract k JOIN player p ON p.id = k.player_id "
                    + "WHERE k.save_id = " + saveId + " AND p.save_id <> k.save_id"));
            // шаблон остался нетронутым
            assertEquals(0, scalar(c, "SELECT COUNT(*) FROM game_save WHERE is_template AND user_club_id IS NOT NULL"));
        }
    }

    private static long scalar(Connection c, String sql) throws Exception {
        try (PreparedStatement ps = c.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {
            rs.next();
            return rs.getLong(1);
        }
    }
}
