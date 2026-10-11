package ru.bbmanager.competition;

import java.sql.Date;
import java.time.LocalDate;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Создаёт чемпионаты сезона: по одному на каждую лигу, где не меньше двух клубов.
 * Расписание двухкруговое (см. ScheduleGenerator), таблицы создаются с нулевыми показателями.
 */
@Service
public class ScheduleService {

    private static final String SQL_SEASONS =
            "SELECT id, year_start FROM season WHERE save_id = ? ORDER BY year_start";
    private static final String SQL_HAS_COMPETITIONS =
            "SELECT COUNT(*) FROM competition WHERE season_id = ?";
    private static final String SQL_LEAGUES = """
            SELECT league_id FROM club WHERE save_id = ?
             GROUP BY league_id HAVING COUNT(*) >= 2 ORDER BY league_id""";
    private static final String SQL_CLUBS =
            "SELECT id FROM club WHERE save_id = ? AND league_id = ? ORDER BY id";
    private static final String SQL_INSERT_COMPETITION =
            "INSERT INTO competition (season_id, league_id) VALUES (?, ?) RETURNING id";
    private static final String SQL_INSERT_MATCH =
            "INSERT INTO match (competition_id, match_date, stage, home_club_id, away_club_id) VALUES (?, ?, ?, ?, ?)";
    private static final String SQL_INSERT_STANDING =
            "INSERT INTO standings (competition_id, club_id) VALUES (?, ?)";

    private final JdbcTemplate jdbc;

    public ScheduleService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Transactional
    public void createSeasonSchedule(int saveId) {
        List<int[]> seasons = jdbc.query(SQL_SEASONS,
                (rs, i) -> new int[] {rs.getInt("id"), rs.getInt("year_start")}, saveId);
        List<Integer> leagues = jdbc.queryForList(SQL_LEAGUES, Integer.class, saveId);

        for (int[] season : seasons) {
            Integer existing = jdbc.queryForObject(SQL_HAS_COMPETITIONS, Integer.class, season[0]);
            if (existing != null && existing > 0) {
                continue; // расписание этого сезона уже создано
            }
            LocalDate firstSaturday = ScheduleGenerator.firstLeagueSaturday(season[1]);
            for (Integer leagueId : leagues) {
                List<Integer> clubs = jdbc.queryForList(SQL_CLUBS, Integer.class, saveId, leagueId);
                Integer competitionId = jdbc.queryForObject(SQL_INSERT_COMPETITION, Integer.class, season[0], leagueId);

                List<ScheduledMatch> matches = ScheduleGenerator.generate(clubs, firstSaturday);
                jdbc.batchUpdate(SQL_INSERT_MATCH, matches, 500, (ps, m) -> {
                    ps.setInt(1, competitionId);
                    ps.setDate(2, Date.valueOf(m.date()));
                    ps.setString(3, "Тур " + m.round());
                    ps.setInt(4, m.homeClubId());
                    ps.setInt(5, m.awayClubId());
                });
                jdbc.batchUpdate(SQL_INSERT_STANDING, clubs, 100, (ps, clubId) -> {
                    ps.setInt(1, competitionId);
                    ps.setInt(2, clubId);
                });
            }
        }
    }
}
