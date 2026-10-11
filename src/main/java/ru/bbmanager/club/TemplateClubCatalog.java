package ru.bbmanager.club;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Клубы для экрана выбора берутся из шаблона мира (сохранение с is_template = TRUE).
 * Клуб закрыт для выбора, если его access_tier не равен open.
 * TODO: кэшировать результат, шаблон меняется редко.
 */
@Service
public class TemplateClubCatalog implements ClubCatalog {

    private final JdbcTemplate jdbc;

    public TemplateClubCatalog(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public List<MapClub> findAll() {
        return jdbc.query("""
                SELECT c.id, c.name, ci.name AS city, ci.latitude, ci.longitude,
                       l.tier, l.name AS league_name,
                       COALESCE(o.type, 'private') AS owner_type,
                       (c.access_tier <> 'open') AS locked
                  FROM club c
                  JOIN game_save s ON s.id = c.save_id AND s.is_template
                  JOIN city ci ON ci.id = c.city_id
                  JOIN league l ON l.id = c.league_id
                  LEFT JOIN owner o ON o.id = c.owner_id
                 WHERE c.is_real
                   AND ci.latitude IS NOT NULL AND ci.longitude IS NOT NULL
                 ORDER BY l.tier, c.name
                """,
                (rs, rowNum) -> new MapClub(
                        rs.getInt("id"),
                        rs.getString("name"),
                        rs.getString("city"),
                        rs.getDouble("latitude"),
                        rs.getDouble("longitude"),
                        rs.getInt("tier"),
                        rs.getString("league_name"),
                        rs.getString("owner_type"),
                        rs.getBoolean("locked")));
    }

    @Override
    public Map<Integer, String> leagueNames() {
        Map<Integer, String> names = new LinkedHashMap<>();
        jdbc.query("SELECT tier, name FROM league ORDER BY tier",
                rs -> {
                    names.put(rs.getInt("tier"), rs.getString("name"));
                });
        return names;
    }
}
