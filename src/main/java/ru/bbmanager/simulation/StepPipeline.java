package ru.bbmanager.simulation;

import java.util.Comparator;
import java.util.List;

/** Выполняет шаги в порядке order(). Не зависит от Spring, поэтому легко тестируется. */
public class StepPipeline {

    private final List<SimulationStep> steps;

    public StepPipeline(List<SimulationStep> steps) {
        this.steps = steps.stream()
                .sorted(Comparator.comparingInt(SimulationStep::order))
                .toList();
    }

    public void run(SimulationContext context) {
        for (SimulationStep step : steps) {
            step.apply(context);
        }
    }
}
