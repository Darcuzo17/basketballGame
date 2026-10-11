package ru.bbmanager.simulation.step;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.sql.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import ru.bbmanager.simulation.SimulationContext;
import ru.bbmanager.simulation.SimulationStep;

/**
 * Завершает сезон, когда сыграны все матчи всех чемпионатов, и сообщает игроку итоговое место.
 * TODO: переход к новому сезону, повышение и вылет, итоги в club_season_summary.
 */
@Component
public class SeasonEndStep implements SimulationStep {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private static final String SQL_FINISH = """
            UPDATE season s SET phase = 'finished'
             WHERE s.save_id = ? AND s.phase = 'regular'
               AND EXISTS (SELECT 1 FROM competition co JOIN match m ON m.competition_id = co.id
                            WHERE co.season_id = s.id)
               AND NOT EXISTS (SELECT 1 FROM competition co JOIN match m ON m.competition_id = co.id
                                WHERE co.season_id = s.id AND NOT m.played)""";
    private static final String SQL_USER_CLUB =
            "SELECT user_club_id FROM game_save WHERE id = ?";
    private static final String SQL_USER_RANK = """
            SELECT t.place FROM (
                SELECT st.club_id,
                       RANK() OVER (ORDER BY st.wins DESC, (st.points_for - st.points_against) DESC) AS place
                  FROM standings st
                  JOIN competition co ON co.id = st.competition_id
                  JOIN season se ON se.id = co.season_id
                  JOIN club uc ON uc.id = ?
                 WHERE se.save_id = ? AND se.phase = 'finished' AND co.league_id = uc.league_id
            ) t WHERE t.club_id = ?""";
    private static final String SQL_EVENT = """
            INSERT INTO game_event (save_id, club_id, event_date, type, payload)
            VALUES (?, ?, ?, 'season_end', ?::jsonb)""";

    private final JdbcTemplate jdbc;

    public SeasonEndStep(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public int order() {
        return 90;
    }

    @Override
    public void apply(SimulationContext ctx) {
        int finished = jdbc.update(SQL_FINISH, ctx.saveId());
        if (finished == 0) {
            return;
        }
        Integer userClub = jdbc.queryForObject(SQL_USER_CLUB, Integer.class, ctx.saveId());
        if (userClub == null) {
            return;
        }
        List<Integer> places = jdbc.queryForList(SQL_USER_RANK, Integer.class, userClub, ctx.saveId(), userClub);
        String place = places.isEmpty() ? "" : " Итоговое место: " + places.get(0) + ".";

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("text", "Сезон завершён." + place);
        try {
            jdbc.update(SQL_EVENT, ctx.saveId(), userClub, Date.valueOf(ctx.date()), MAPPER.writeValueAsString(payload));
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Не удалось сформировать событие конца сезона", e);
        }
    }
}
