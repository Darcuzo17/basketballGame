package ru.bbmanager.competition;

import java.time.LocalDate;

/** Запланированный матч чемпионата. */
public record ScheduledMatch(int round, LocalDate date, int homeClubId, int awayClubId) {
}
