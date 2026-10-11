package ru.bbmanager.competition;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/** Чтение данных чемпионата для экранов: таблица, ближайший матч, последние события. */
@Service
public class LeagueQueryService {

    public record StandingRow(int place, int clubId, String club, int played, int wins, int losses, int diff) {
    }

    public record NextMatch(LocalDate date, String stage, String home, String away, boolean userIsHome) {
    }

    public record EventLine(LocalDate date, String type, String text) {
    }

    private static final String SQL_STANDINGS = """
            SELECT c.id AS club_id, c.name, st.wins, st.losses, st.points_for, st.points_against
              FROM game_save gs
              JOIN club uc ON uc.id = gs.user_club_id
              JOIN season se ON se.save_id = gs.id
                            AND se.year_start = (SELECT MAX(year_start) FROM season WHERE save_id = gs.id)
              JOIN competition co ON co.season_id = se.id AND co.league_id = uc.league_id
              JOIN standings st ON st.competition_id = co.id
              JOIN club c ON c.id = st.club_id
             WHERE gs.id = ?
             ORDER BY st.wins DESC, (st.points_for - st.points_against) DESC, c.name""";
    private static final String SQL_NEXT_MATCH = """
            SELECT m.match_date, m.stage, hc.name AS home, ac.name AS away,
                   (m.home_club_id = ?) AS user_is_home
              FROM match m
              JOIN competition co ON co.id = m.competition_id
              JOIN season se ON se.id = co.season_id
              JOIN club hc ON hc.id = m.home_club_id
              JOIN club ac ON ac.id = m.away_club_id
             WHERE se.save_id = ? AND NOT m.played
               AND (m.home_club_id = ? OR m.away_club_id = ?)
             ORDER BY m.match_date, m.id
             LIMIT 1""";
    private static final String SQL_RECENT_EVENTS = """
            SELECT event_date, type, payload->>'text' AS text
              FROM game_event WHERE save_id = ?
             ORDER BY event_date DESC, id DESC LIMIT ?""";
    private static final String SQL_PHASE = """
            SELECT phase FROM season WHERE save_id = ? ORDER BY year_start DESC LIMIT 1""";

    private final JdbcTemplate jdbc;

    public LeagueQueryService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Таблица чемпионата, в котором играет клуб игрока, в текущем сезоне. */
    public List<StandingRow> standings(int saveId) {
        List<StandingRow> rows = new ArrayList<>();
        jdbc.query(SQL_STANDINGS, rs -> {
            int wins = rs.getInt("wins");
            int losses = rs.getInt("losses");
            rows.add(new StandingRow(rows.size() + 1, rs.getInt("club_id"), rs.getString("name"),
                    wins + losses, wins, losses, rs.getInt("points_for") - rs.getInt("points_against")));
        }, saveId);
        return rows;
    }

    public Optional<NextMatch> nextMatch(int saveId, int userClubId) {
        return jdbc.query(SQL_NEXT_MATCH,
                (rs, i) -> new NextMatch(rs.getDate("match_date").toLocalDate(), rs.getString("stage"),
                        rs.getString("home"), rs.getString("away"), rs.getBoolean("user_is_home")),
                userClubId, saveId, userClubId, userClubId).stream().findFirst();
    }

    public List<EventLine> recentEvents(int saveId, int limit) {
        return jdbc.query(SQL_RECENT_EVENTS,
                (rs, i) -> new EventLine(rs.getDate("event_date").toLocalDate(), rs.getString("type"),
                        rs.getString("text") == null ? rs.getString("type") : rs.getString("text")),
                saveId, limit);
    }

    /** Фаза текущего сезона: offseason, regular, playoff, finished. */
    public String seasonPhase(int saveId) {
        List<String> phases = jdbc.queryForList(SQL_PHASE, String.class, saveId);
        return phases.isEmpty() ? "offseason" : phases.get(0);
    }
}
