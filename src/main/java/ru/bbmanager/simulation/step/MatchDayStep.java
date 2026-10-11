package ru.bbmanager.simulation.step;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.sql.Date;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Set;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowCallbackHandler;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;
import ru.bbmanager.competition.MatchResult;
import ru.bbmanager.competition.MatchSimulator;
import ru.bbmanager.competition.MatchSummary;
import ru.bbmanager.competition.TeamRating;
import ru.bbmanager.simulation.SimulationContext;
import ru.bbmanager.simulation.SimulationStep;

/**
 * Играет все матчи сохранения, назначенные на этот день: счёт, таблицы, усталость.
 * Для матчей клуба игрока создаётся событие match_result (оно останавливает режим «до события»).
 * Результат повторяем: генератор случайных чисел зависит от сохранения и матча (см. MatchSimulator.seedFor).
 * TODO: посещаемость и выручка от билетов, статистика игроков, травмы, форма, ажиотаж.
 */
@Component
public class MatchDayStep implements SimulationStep {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private static final String SQL_MATCHES = """
            SELECT m.id, m.competition_id, m.home_club_id, m.away_club_id,
                   hc.name AS home_name, ac.name AS away_name
              FROM match m
              JOIN competition co ON co.id = m.competition_id
              JOIN season s ON s.id = co.season_id
              JOIN club hc ON hc.id = m.home_club_id
              JOIN club ac ON ac.id = m.away_club_id
             WHERE s.save_id = ? AND m.match_date = ? AND NOT m.played
             ORDER BY m.id""";
    private static final String SQL_PLAYERS = """
            SELECT club_id, attack, defense, physical, basketball_iq, form, fatigue
              FROM player
             WHERE save_id = :saveId AND club_id IN (:ids)
               AND (injury_until IS NULL OR injury_until < :date)""";
    private static final String SQL_COACHES =
            "SELECT club_id, tactics_skill FROM coach WHERE club_id IN (:ids)";
    private static final String SQL_USER_CLUB =
            "SELECT user_club_id FROM game_save WHERE id = ?";
    private static final String SQL_UPDATE_MATCH = """
            UPDATE match SET home_score = ?, away_score = ?, quarter_scores = ?::jsonb,
                             summary = ?, played = TRUE
             WHERE id = ?""";
    private static final String SQL_UPDATE_STANDING = """
            UPDATE standings SET wins = wins + ?, losses = losses + ?,
                                 points_for = points_for + ?, points_against = points_against + ?
             WHERE competition_id = ? AND club_id = ?""";
    private static final String SQL_TIRE =
            "UPDATE player SET fatigue = LEAST(100, fatigue + 12) WHERE save_id = :saveId AND club_id IN (:ids)";
    private static final String SQL_EVENT = """
            INSERT INTO game_event (save_id, club_id, event_date, type, payload)
            VALUES (?, ?, ?, 'match_result', ?::jsonb)""";

    private final JdbcTemplate jdbc;
    private final NamedParameterJdbcTemplate named;
    private final MatchSimulator simulator = new MatchSimulator();

    public MatchDayStep(JdbcTemplate jdbc, NamedParameterJdbcTemplate named) {
        this.jdbc = jdbc;
        this.named = named;
    }

    @Override
    public int order() {
        return 50;
    }

    @Override
    public void apply(SimulationContext ctx) {
        List<MatchRow> matches = jdbc.query(SQL_MATCHES,
                (rs, i) -> new MatchRow(rs.getInt("id"), rs.getInt("competition_id"),
                        rs.getInt("home_club_id"), rs.getInt("away_club_id"),
                        rs.getString("home_name"), rs.getString("away_name")),
                ctx.saveId(), Date.valueOf(ctx.date()));
        if (matches.isEmpty()) {
            return;
        }

        Set<Integer> clubIds = new LinkedHashSet<>();
        for (MatchRow m : matches) {
            clubIds.add(m.homeId());
            clubIds.add(m.awayId());
        }
        Map<Integer, Double> strength = loadStrengths(ctx, clubIds);
        Integer userClub = jdbc.queryForObject(SQL_USER_CLUB, Integer.class, ctx.saveId());

        for (MatchRow m : matches) {
            Random random = new Random(MatchSimulator.seedFor(ctx.saveId(), m.id()));
            MatchResult result = simulator.simulate(strength.get(m.homeId()), strength.get(m.awayId()), random);
            String summary = MatchSummary.describe(m.homeName(), m.awayName(), result);

            jdbc.update(SQL_UPDATE_MATCH, result.homeScore(), result.awayScore(), result.periodsJson(), summary, m.id());
            boolean homeWon = result.homeWon();
            jdbc.update(SQL_UPDATE_STANDING, homeWon ? 1 : 0, homeWon ? 0 : 1,
                    result.homeScore(), result.awayScore(), m.competitionId(), m.homeId());
            jdbc.update(SQL_UPDATE_STANDING, homeWon ? 0 : 1, homeWon ? 1 : 0,
                    result.awayScore(), result.homeScore(), m.competitionId(), m.awayId());

            if (userClub != null && (userClub == m.homeId() || userClub == m.awayId())) {
                boolean userWon = (userClub == m.homeId()) == homeWon;
                writeEvent(ctx, userClub, m, result, summary, userWon);
            }
        }

        Map<String, Object> tireParams = new HashMap<>();
        tireParams.put("saveId", ctx.saveId());
        tireParams.put("ids", clubIds);
        named.update(SQL_TIRE, tireParams);
    }

    private Map<Integer, Double> loadStrengths(SimulationContext ctx, Set<Integer> clubIds) {
        Map<String, Object> params = new HashMap<>();
        params.put("saveId", ctx.saveId());
        params.put("ids", clubIds);
        params.put("date", Date.valueOf(ctx.date()));

        Map<Integer, List<Double>> ratings = new HashMap<>();
        named.query(SQL_PLAYERS, params, (RowCallbackHandler) rs ->
                ratings.computeIfAbsent(rs.getInt("club_id"), k -> new ArrayList<>())
                        .add(TeamRating.playerRating(rs.getInt("attack"), rs.getInt("defense"),
                                rs.getInt("physical"), rs.getInt("basketball_iq"),
                                rs.getInt("form"), rs.getInt("fatigue"))));

        Map<Integer, Integer> coaches = new HashMap<>();
        named.query(SQL_COACHES, Map.of("ids", clubIds), (RowCallbackHandler) rs ->
                coaches.put(rs.getInt("club_id"), rs.getInt("tactics_skill")));

        Map<Integer, Double> strength = new HashMap<>();
        for (Integer clubId : clubIds) {
            strength.put(clubId, TeamRating.teamRating(
                    ratings.getOrDefault(clubId, List.of()), coaches.getOrDefault(clubId, 50)));
        }
        return strength;
    }

    private void writeEvent(SimulationContext ctx, int userClub, MatchRow m, MatchResult result,
                            String summary, boolean userWon) {
        String headline = (userWon ? "Победа: " : "Поражение: ")
                + m.homeName() + " " + result.homeScore() + ":" + result.awayScore() + " " + m.awayName();
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("matchId", m.id());
        payload.put("home", m.homeName());
        payload.put("away", m.awayName());
        payload.put("homeScore", result.homeScore());
        payload.put("awayScore", result.awayScore());
        payload.put("won", userWon);
        payload.put("text", headline);
        payload.put("summary", summary);
        try {
            jdbc.update(SQL_EVENT, ctx.saveId(), userClub, Date.valueOf(ctx.date()), MAPPER.writeValueAsString(payload));
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Не удалось сформировать событие матча", e);
        }
    }

    private record MatchRow(int id, int competitionId, int homeId, int awayId, String homeName, String awayName) {
    }
}
