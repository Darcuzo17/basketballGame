package ru.bbmanager.simulation;

import java.time.LocalDate;

/** Данные, доступные шагам расчёта дня. */
public record SimulationContext(int saveId, LocalDate date) {
}
