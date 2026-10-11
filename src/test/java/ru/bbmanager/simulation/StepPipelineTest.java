package ru.bbmanager.simulation;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

class StepPipelineTest {

    @Test
    void runsStepsInOrderRegardlessOfRegistrationOrder() {
        List<String> calls = new ArrayList<>();
        SimulationStep late = step(20, "late", calls);
        SimulationStep early = step(10, "early", calls);

        new StepPipeline(List.of(late, early))
                .run(new SimulationContext(1, LocalDate.of(2026, 7, 1)));

        assertEquals(List.of("early", "late"), calls);
    }

    private static SimulationStep step(int order, String name, List<String> calls) {
        return new SimulationStep() {
            @Override
            public int order() {
                return order;
            }

            @Override
            public void apply(SimulationContext context) {
                calls.add(name);
            }
        };
    }
}
