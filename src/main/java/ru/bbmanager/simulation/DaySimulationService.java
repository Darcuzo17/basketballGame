package ru.bbmanager.simulation;

import java.sql.Date;
import java.time.Instant;
import java.time.LocalDate;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import ru.bbmanager.game.GameSave;
import ru.bbmanager.game.GameSaveRepository;

/**
 * Расчёт игровых дней на сервере. Один день всегда считается одной транзакцией:
 * либо день посчитан целиком, либо ничего не изменилось.
 * Режим «до события» считает дни по одному, каждый в своей транзакции, и останавливается на событии.
 */
@Service
public class DaySimulationService {

    /** Предохранитель: за один запуск не больше столько дней. */
    static final int MAX_DAYS_PER_RUN = 400;

    private static final String SQL_STOP_EVENT = """
            SELECT type FROM game_event
             WHERE save_id = ? AND event_date = ?
               AND (requires_action OR type IN ('match_result', 'season_end'))
             ORDER BY id LIMIT 1""";
    private static final String SQL_SEASON_FINISHED =
            "SELECT COUNT(*) FROM season WHERE save_id = ? AND phase = 'finished'";

    public enum StopReason { EVENT, SEASON_FINISHED, LIMIT }

    /** Итог запуска «до события»: сколько дней прошло, новая дата и причина остановки. */
    public record AdvanceResult(int days, LocalDate date, StopReason reason) {
    }

    private final GameSaveRepository saves;
    private final StepPipeline pipeline;
    private final TransactionTemplate tx;
    private final JdbcTemplate jdbc;

    public DaySimulationService(GameSaveRepository saves,
                                ObjectProvider<SimulationStep> steps,
                                TransactionTemplate tx,
                                JdbcTemplate jdbc) {
        this.saves = saves;
        this.pipeline = new StepPipeline(steps.orderedStream().toList());
        this.tx = tx;
        this.jdbc = jdbc;
    }

    /** Один день. Возвращает новую игровую дату. */
    @Transactional
    public LocalDate advanceDay(int saveId) {
        return doAdvance(saveId);
    }

    /** Считает дни, пока не случится событие, сезон не закончится или не сработает предохранитель. */
    public AdvanceResult advanceUntilEvent(int saveId) {
        if (isSeasonFinished(saveId)) {
            return new AdvanceResult(0, currentDate(saveId), StopReason.SEASON_FINISHED);
        }
        int days = 0;
        LocalDate date = currentDate(saveId);
        while (days < MAX_DAYS_PER_RUN) {
            date = tx.execute(status -> doAdvance(saveId));
            days++;
            String eventType = jdbc.query(SQL_STOP_EVENT,
                    rs -> rs.next() ? rs.getString(1) : null,
                    saveId, Date.valueOf(date.minusDays(1)));
            if (eventType != null) {
                return new AdvanceResult(days, date,
                        "season_end".equals(eventType) ? StopReason.SEASON_FINISHED : StopReason.EVENT);
            }
        }
        return new AdvanceResult(days, date, StopReason.LIMIT);
    }

    private LocalDate doAdvance(int saveId) {
        GameSave save = saves.findById(saveId).orElseThrow();
        LocalDate today = save.getGameDate();
        pipeline.run(new SimulationContext(saveId, today));
        save.setGameDate(today.plusDays(1));
        save.setLastPlayedAt(Instant.now());
        return save.getGameDate();
    }

    private boolean isSeasonFinished(int saveId) {
        Integer count = jdbc.queryForObject(SQL_SEASON_FINISHED, Integer.class, saveId);
        return count != null && count > 0;
    }

    private LocalDate currentDate(int saveId) {
        return saves.findById(saveId).orElseThrow().getGameDate();
    }
}
