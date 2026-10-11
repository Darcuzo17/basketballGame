package ru.bbmanager.simulation.step;

import java.sql.Date;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import ru.bbmanager.simulation.SimulationContext;
import ru.bbmanager.simulation.SimulationStep;

/** Переводит сезон из межсезонья в регулярный чемпионат, когда наступает дата первого матча. */
@Component
public class SeasonPhaseStep implements SimulationStep {

    private static final String SQL_START_REGULAR = """
            UPDATE season s SET phase = 'regular'
             WHERE s.save_id = ? AND s.phase = 'offseason'
               AND ?::date >= (SELECT MIN(m.match_date)
                                 FROM competition co JOIN match m ON m.competition_id = co.id
                                WHERE co.season_id = s.id)""";

    private final JdbcTemplate jdbc;

    public SeasonPhaseStep(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public int order() {
        return 10;
    }

    @Override
    public void apply(SimulationContext context) {
        jdbc.update(SQL_START_REGULAR, context.saveId(), Date.valueOf(context.date()));
    }
}
