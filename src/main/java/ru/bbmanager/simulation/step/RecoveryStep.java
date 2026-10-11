package ru.bbmanager.simulation.step;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import ru.bbmanager.simulation.SimulationContext;
import ru.bbmanager.simulation.SimulationStep;

/** Ежедневное восстановление: усталость игроков снижается. */
@Component
public class RecoveryStep implements SimulationStep {

    private static final String SQL_RECOVER = """
            UPDATE player SET fatigue = GREATEST(0, fatigue - 3)
             WHERE save_id = ? AND fatigue > 0""";

    private final JdbcTemplate jdbc;

    public RecoveryStep(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public int order() {
        return 20;
    }

    @Override
    public void apply(SimulationContext context) {
        jdbc.update(SQL_RECOVER, context.saveId());
    }
}
